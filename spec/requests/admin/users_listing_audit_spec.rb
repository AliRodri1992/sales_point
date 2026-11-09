# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Audited users listing', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, user: administrator, organization:)
    sign_in administrator
  end

  it 'shows local membership status in desktop and mobile layouts' do
    target = create(:user, email: 'status-specific@example.com')
    create(:organization_membership, user: target, organization:, account_status: :suspended)

    get admin_users_path

    document = Nokogiri::HTML(response.body)
    card = document.css('article[data-skeleton-record]').find { |node| node.text.include?(target.email) }
    row = document.css('tr[data-skeleton-record]').find { |node| node.text.include?(target.email) }
    label = I18n.t('admin.users.statuses.suspended')
    expect(card.text).to include(label)
    expect(row.text).to include(label)
  end

  it 'distinguishes local active membership from globally inaccessible account status' do
    target = create(:user, email: 'globally-suspended@example.com', status: :suspended)
    create(:organization_membership, user: target, organization:, account_status: :active)

    get admin_users_path

    document = Nokogiri::HTML(response.body)
    row = document.css('tr[data-skeleton-record]').find { |node| node.text.include?(target.email) }
    card = document.css('article[data-skeleton-record]').find { |node| node.text.include?(target.email) }
    message = I18n.t('admin.users.ui.effective_access_unavailable')
    expect(row.text).to include(message)
    expect(card.text).to include(message)
  end

  it 'matches status metrics to non-deleted users in the directory' do
    hidden = create(:user, status: :deleted, deleted_at: Time.current)
    create(:organization_membership, user: hidden, organization:, account_status: :active)

    get admin_users_path

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    metric_label = I18n.t('admin.users.ui.metrics.active')
    cards = doc.css('section[aria-label] > div')
    active_card = cards.find { |card| card.text.include?(metric_label) }
    expect(active_card).to be_present
    expect(active_card.css('p').last.text.strip).to eq('1')
    expect(response.body).not_to include(hidden.email)
  end

  it 'exposes the active sort direction to screen readers' do
    get admin_users_path, params: { sort: 'users.username', direction: 'asc' }

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('th[aria-sort="ascending"]')).to be_present
    expect(doc.css('th[aria-sort="none"]')).not_to be_empty
  end

  it 'excludes revoked assignments from the role filter' do
    target = create(:user, email: 'revoked-search@example.com')
    create(:organization_membership, user: target, organization:)
    role = create(:system_role, :system, code: 'revoked_search')
    create(:user_role, user: target, system_role: role, deleted_at: 2.days.ago)

    get admin_users_path, params: { role: role.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(target.email)
  end

  it 'uses full navigation for filters, sorting and deletion' do
    target = create(:user, email: 'navigation-audit@example.com')
    create(:organization_membership, user: target, organization:)

    get admin_users_path

    document = Nokogiri::HTML(response.body)
    filters = document.at_css('form[action="/admin/users"]')
    expect(filters['data-turbo-frame']).to eq('_top')
    expect(filters['data-controller']).to include('users-filters')
    expect(filters['data-action']).to include('change->users-filters#filterChanged')
    sort = document.css('a').find { |link| link['href']&.include?('sort=users') }
    expect(sort['data-turbo-frame']).to eq('_top')
    deactivation = document.at_css('dialog[data-user-deactivation-target="dialog"]')
    expect(deactivation).to be_present
    expect(deactivation.at_css('input[name="transition"]')['value']).to eq('deleted')
    expect(document.at_css('textarea#users-deactivation-reason[required]')).to be_nil
  end

  it 'does not issue branch lookups per row when roles are displayed' do
    branch = create(:branch, organization:, operational_state: 'active')
    role = create(:system_role, :branch, code: 'bulk_list_branch_role')
    8.times do |index|
      target = create(:user, email: "bulk-role-#{index}@example.com")
      create(:organization_membership, organization:, user: target)
      create(:user_role, user: target, branch:, system_role: role)
    end

    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _started, _finished, _id, data|
      queries << data[:sql] if data[:sql].to_s.include?('FROM "branches"')
    end
    begin
      get admin_users_path
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    expect(response).to have_http_status(:ok)
    expect(queries.length).to be <= 6
  end

  it 'shows status history on an authorized user detail' do
    target = create(:user, email: 'history-visible@example.com')
    create(:organization_membership, user: target, organization:)
    UserStatusEvent.create!(
      user: target, actor: administrator, organization:, from_status: 'pending',
      to_status: 'active', reason: 'Membership history is visible'
    )

    get admin_user_path(target)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Membership history is visible')
  end
end
