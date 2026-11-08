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
