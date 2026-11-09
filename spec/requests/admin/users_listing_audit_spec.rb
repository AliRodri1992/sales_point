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
    deletion = document.css('a').find { |link| link['href']&.include?("users/#{target.id}/status/edit") }
    expect(deletion['data-turbo-frame']).to eq('_top')
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
