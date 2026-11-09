# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Role permission persistence and authorization regressions', type: :request do
  let!(:organization) { create(:organization) }
  let!(:actor) { create(:user, :english) }
  let!(:membership) { create(:organization_membership, organization:, user: actor) }
  let!(:super_role) { create(:system_role, :system, code: 'super_admin') }
  let!(:grant) { create(:user_role, user: actor, system_role: super_role, organization:) }
  let!(:role) { create(:system_role, :system, code: 'store_operations') }

  before { sign_in actor }

  it 'preserves inactive assignments on metadata-only changes' do
    dormant = create(:permission, code: 'store.dormant', status: :inactive)
    create(:system_role_permission, system_role: role, permission: dormant)

    expect do
      patch system_role_path(role), params: { system_role: { description: 'New description' } }
    end.not_to change(SystemRolePermissionAuditEvent.where(system_role: role), :count)

    expect(response).to redirect_to(system_role_path(role))
    expect(role.permissions.reload).to include(dormant)
    expect(role.reload.description).to eq('New description')
  end

  it 'retains unselectable assignments even during explicit permission edits' do
    dormant = create(:permission, code: 'store.dormant', status: :inactive)
    active_permission = create(:permission, code: 'store.active')
    create(:system_role_permission, system_role: role, permission: dormant)

    patch permissions_system_role_path(role), params: { permission_ids: [active_permission.id] }

    expect(response).to redirect_to(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(dormant, active_permission)
    event = role.permission_audit_events.last
    expect(event.added_permission_codes).to include(active_permission.code)
    expect(event.removed_permission_codes).to be_empty
  end

  it 'rejects an action when its base access permission is inactive' do
    access = create(:permission, code: 'languages.access')
    action = create(:permission, code: 'languages.update')
    access.update!(status: 'inactive')

    patch permissions_system_role_path(role), params: { permission_ids: [action.id] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(role.permissions.reload).not_to include(action)
    expect(Nokogiri::HTML(response.body).at_css('#system_role_permission_ids_error')).to be_present
  end

  it 'rejects a role administrator whose last organization membership is revoked' do
    membership.update!(status: :inactive)
    get system_roles_path
    expect(response).to have_http_status(:forbidden)

    get system_role_path(role)
    expect(response).to have_http_status(:forbidden)

    post system_roles_path, params: { system_role: { name: 'Unauthorized', role_type: 'system' } }
    expect(response).to have_http_status(:forbidden)

    patch permissions_system_role_path(role), params: { permission_ids: [] }
    expect(response).to have_http_status(:forbidden)
  end
end
