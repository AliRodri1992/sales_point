# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shared system role tenant isolation', type: :request do
  let!(:own) { create(:organization) }
  let!(:other) { create(:organization) }
  let!(:actor) { create(:user, :english) }
  let!(:shared_role) { create(:system_role, :system, code: 'shared_workspace') }
  let!(:permission) { create(:permission, code: 'workspace.read') }

  before do
    create(:organization_membership, organization: own, user: actor)
    create(:user_role, organization: own, user: actor,
                       system_role: create(:system_role, :system, code: 'super_admin'))
    create(:system_role_permission, system_role: shared_role, permission:)
    foreign_user = create(:user)
    create(:organization_membership, organization: other, user: foreign_user)
    create(:user_role, organization: other, user: foreign_user, system_role: shared_role)
    sign_in actor
  end

  it 'refuses permission and metadata edits affecting a second tenant' do
    patch system_role_path(shared_role), params: { system_role: { name: 'Unauthorized new name' } }
    expect(response).to have_http_status(:forbidden)
    expect(shared_role.reload.name).not_to eq('Unauthorized new name')

    expect do
      patch permissions_system_role_path(shared_role), params: { permission_ids: [] }
    end.not_to change(SystemRolePermissionAuditEvent, :count)
    expect(response).to have_http_status(:forbidden)
    expect(shared_role.permissions.reload).to include(permission)
  end

  it 'refuses status reviews and hides global permission audit history' do
    get status_review_system_role_path(shared_role, target: 'inactive')
    expect(response).to have_http_status(:forbidden)

    get system_role_path(shared_role)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Permission change history', 'Status history')
  end

  it 'allows editing a role assigned only in its own organization' do
    local = create(:system_role, :system, code: 'single_tenant_workspace')
    create(:user_role, organization: own, user: actor, system_role: local)

    patch system_role_path(local), params: { system_role: { description: 'Only local use' } }
    expect(response).to redirect_to(system_role_path(local))
    expect(local.reload.description).to eq('Only local use')
  end
end
