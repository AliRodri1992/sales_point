# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Role permission privilege boundaries', type: :request do
  let!(:super_role) { create(:system_role, :system, code: 'super_admin') }
  let!(:actor) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations', code: 'operations') }
  let!(:access) { create(:permission, code: 'languages.access') }
  let!(:action) { create(:permission, code: 'languages.update') }

  before do
    create(:user_role, user: actor, system_role: super_role)
    sign_in actor
  end

  it 'requires base access on the server and preserves assignments when invalid' do
    create(:system_role_permission, system_role: role, permission: access)
    patch permissions_system_role_path(role), params: { permission_ids: [action.id] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(role.permissions.reload).to include(access)
    expect(role.permissions.reload).not_to include(action)
    expect(Nokogiri::HTML(response.body).at_css('#system_role_permission_ids_error')).to be_present
    expect(SystemRolePermissionAuditEvent.where(system_role: role)).to be_empty
  end

  it 'rejects missing base access on creation' do
    post system_roles_path, params: {
      system_role: { name: 'New special', role_type: 'system', status: 'inactive' },
      permission_ids: [action.id]
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(SystemRole.find_by(name: 'New special')).to be_nil
  end

  it 'records permission additions and removals with the acting user' do
    patch permissions_system_role_path(role), params: { permission_ids: [access.id, action.id] }
    expect(response).to redirect_to(system_role_path(role))
    event = SystemRolePermissionAuditEvent.where(system_role: role).last
    expect(event.actor).to eq(actor)
    expect(event.added_permission_codes).to contain_exactly('languages.access', 'languages.update')
    expect(event.removed_permission_codes).to eq([])

    patch permissions_system_role_path(role), params: { permission_ids: [access.id] }
    expect(response).to redirect_to(system_role_path(role))
    event = SystemRolePermissionAuditEvent.where(system_role: role).last
    expect(event.added_permission_codes).to eq([])
    expect(event.removed_permission_codes).to eq(['languages.update'])
    get system_role_path(role)
    expect(response.body).to include('Permission change history', 'languages.update')
  end

  it 'does not create audit rows if nothing changes' do
    patch permissions_system_role_path(role), params: { permission_ids: [access.id] }
    expect do
      patch permissions_system_role_path(role), params: { permission_ids: [access.id] }
    end.not_to change(SystemRolePermissionAuditEvent, :count)
  end

  it 'prevents tenant administrators from changing shared global roles' do
    administrator = create(:user, :english)
    create(:user_role, user: administrator, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in administrator

    get system_roles_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('href="/system_roles/new"')
    get system_role_path(role)
    expect(response).to have_http_status(:ok)
    post system_roles_path, params: { system_role: { name: 'Unauthorized', role_type: 'system' } }
    expect(response).to have_http_status(:forbidden)
    patch permissions_system_role_path(role), params: { permission_ids: [access.id] }
    expect(response).to have_http_status(:forbidden)
    get status_review_system_role_path(role, target: 'inactive')
    expect(response).to have_http_status(:forbidden)
  end
end
