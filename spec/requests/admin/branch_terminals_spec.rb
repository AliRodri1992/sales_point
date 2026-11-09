# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branch terminal administration', type: :request do
  let(:organization) { create(:organization, :with_settings) }
  let(:admin_user) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:branch) { create(:branch, organization:, name: 'Main branch') }

  before do
    create(:organization_membership, organization:, user: admin_user)
    sign_in admin_user
  end

  it 'configures an inactive terminal and can enable it at an active branch' do
    post add_terminal_admin_branch_path(branch), params: { terminal: { name: 'Front register' } }
    expect(response).to have_http_status(:see_other)
    terminal = branch.terminals.last
    expect(terminal).to have_attributes(name: 'Front register', status: 'inactive')

    patch change_terminal_admin_branch_path(branch),
          params: { terminal_id: terminal.id, terminal_status: 'active' }
    expect(response).to have_http_status(:see_other)
    expect(terminal.reload).to be_active
  end

  it 'omits retired terminals from the detail, operational count and actions' do
    current = create(:terminal, branch:, name: 'Current register', status: 'inactive')
    retired = create(:terminal, branch:, name: 'Retired register', status: 'inactive')
    retired.update!(deleted_at: Time.current)

    get admin_branch_path(branch)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    section = document.at_css('#branch-detail-operations')
    expect(section.text).to include(current.name)
    expect(section.text).not_to include(retired.name)
    totals = section.css('.branch-operation-stats > div')
    terminals = totals.find { |item| item.at_css('dt')&.text&.strip == I18n.t('admin.branch_workspace.terminals') }
    expect(terminals.at_css('dd').text.strip).to eq('1')
    expect(section.css("form input[name='terminal_id'][value='#{retired.id}']")).to be_empty
  end

  it 'rejects changes to a retired terminal without changing its state' do
    retired = create(:terminal, branch:, name: 'Retired register', status: 'inactive')
    retired.update!(deleted_at: Time.current)

    patch change_terminal_admin_branch_path(branch),
          params: { terminal_id: retired.id, terminal_status: 'active' }

    expect(response).to have_http_status(:not_found)
    expect(retired.reload).to be_inactive
    expect(retired.deleted_at).to be_present
  end

  it 'allocates a historical non-reused code with a bounded number of queries' do
    20.times do |number|
      create(:terminal, branch:, code: format('POS-%03d', number + 1), status: 'inactive')
    end
    branch.terminals.find_by!(code: 'POS-020').update!(deleted_at: Time.current)
    other = create(:branch, organization:, name: 'Another branch')
    create(:terminal, branch: other, code: 'POS-900', status: 'inactive')

    terminal_queries = []
    callback = lambda do |_name, _started, _finished, _identifier, payload|
      sql = payload[:sql].to_s
      terminal_queries << sql if sql.match?(/FROM "terminals"/i)
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      post add_terminal_admin_branch_path(branch), params: { terminal: { name: 'Additional register' } }
    end

    expect(response).to have_http_status(:see_other)
    expect(branch.terminals.find_by!(name: 'Additional register').code).to eq('POS-021')
    expect(terminal_queries.count { |sql| sql.include?('MAX(SUBSTRING(code FROM 5)::numeric)') }).to eq(1)
    expect(terminal_queries.grep(/SELECT/i).size).to be <= 4
  end

  it 'shows a model validation error under the terminal name field' do
    post add_terminal_admin_branch_path(branch), params: { terminal: { name: '' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('branch-terminal-name-error')
    expect(branch.terminals.count).to eq(0)
  end

  it 'requires disabling terminals before suspension' do
    terminal = create(:terminal, branch:, status: 'active')

    patch transition_status_admin_branch_path(branch),
          params: { to_status: 'suspended', reason: 'Annual maintenance' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(branch.reload).to be_active

    patch change_terminal_admin_branch_path(branch),
          params: { terminal_id: terminal.id, terminal_status: 'inactive' }
    expect(response).to have_http_status(:see_other)

    patch transition_status_admin_branch_path(branch),
          params: { to_status: 'suspended', reason: 'Annual maintenance' }
    expect(response).to have_http_status(:see_other)
    expect(branch.reload).to be_suspended
  end

  it 'does not expose a branch to a member without branch access' do
    employee = create(:user)
    create(:organization_membership, organization:, user: employee)
    sign_out admin_user
    sign_in employee

    post add_terminal_admin_branch_path(branch), params: { terminal: { name: 'Unauthorized' } }
    expect(response).to have_http_status(:not_found)
    expect(branch.terminals.count).to eq(0)
  end
end
