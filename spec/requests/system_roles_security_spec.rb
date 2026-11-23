# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Role permission privilege boundaries', type: :request do
  let!(:super_role) { create(:system_role, :system, code: 'super_admin') }
  let!(:actor) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations', code: 'operations') }
  let!(:access) { create(:permission, code: 'languages.access') }
  let!(:action) { create(:permission, code: 'languages.update') }

  before do
    create(:organization_membership, user: actor)
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

  it 'requires each commercial action to be paired with its own module access' do
    price_list_access = create(:permission, code: 'price_lists.access')
    promotion_access = create(:permission, code: 'promotions.access')
    archive = create(:permission, code: 'promotions.archive')

    patch permissions_system_role_path(role), params: { permission_ids: [price_list_access.id, archive.id] }
    expect(response).to have_http_status(:unprocessable_content)
    expect(role.permissions.reload).not_to include(archive)

    patch permissions_system_role_path(role), params: { permission_ids: [promotion_access.id, archive.id] }
    expect(response).to redirect_to(system_role_path(role))
    expect(role.permissions.reload).to match_array([promotion_access, archive])
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

  context 'when signed in as an administrator' do
    let(:administrator) { create(:user, :english) }
    let(:organization) { create(:organization) }
    let(:administrator_role) { create(:system_role, :system, code: 'administrator') }

    before do
      create(:organization_membership, user: administrator, organization:)
      create(:user_role, user: administrator, system_role: administrator_role, organization:)
      create(:user_role, user: administrator, system_role: role, organization:)
      sign_in administrator
    end

    it 'offers an editable permission workspace with protected role details' do
      get system_roles_path
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      card = document.at_css("[data-role-card][href='#{system_role_path(role)}']")
      expect(card.text).to include('Manage permissions')
      [administrator_role, super_role].each do |protected_role|
        card = document.at_css("[data-role-card][href='#{system_role_path(protected_role)}']")
        expect(card.text).to include('View permissions')
      end
      expect(response.body).not_to include('href="/system_roles/new"')

      get system_role_path(role)
      workspace = Nokogiri::HTML(response.body).at_css('[data-permissions-mode="edit"]')
      expect(workspace).to be_present
      expect(workspace.at_css("form[action='#{permissions_system_role_path(role)}']")).to be_present
      expect(workspace.at_css('fieldset[disabled] #system_role_name')).to be_present
      expect(workspace.at_css("#permission_#{access.id}:not([disabled])")).to be_present
      expect(response.body).not_to include('Permission change history', 'Status history')
    end

    it 'persists local permissions and audits the administrator without changing metadata' do
      patch permissions_system_role_path(role), params: {
        permission_ids: [access.id, action.id], system_role: { name: 'Unauthorized', status: 'inactive' }
      }

      expect(response).to redirect_to(system_role_path(role))
      expect(role.reload).to have_attributes(name: 'Operations', status: 'active')
      expect(role.permissions).to contain_exactly(access, action)
      expect(role.permission_audit_events.last.actor).to eq(administrator)
    end

    it 'does not allow direct role metadata, creation or lifecycle changes' do
      post system_roles_path, params: { system_role: { name: 'Unauthorized', role_type: 'system' } }
      expect(response).to have_http_status(:forbidden)
      patch system_role_path(role), params: { system_role: { name: 'Unauthorized' } }
      expect(response).to have_http_status(:forbidden)
      get status_review_system_role_path(role, target: 'inactive')
      expect(response).to have_http_status(:forbidden)
    end

    it 'blocks changes to either protected role' do
      [super_role, administrator_role].each do |protected_role|
        patch permissions_system_role_path(protected_role), params: { permission_ids: [] }
        expect(response).to have_http_status(:forbidden)
        expect(protected_role.permissions.reload).to include(access, action)
      end
    end

    it 'blocks edits to roles used by another organization' do
      other = create(:organization)
      foreign_user = create(:user)
      create(:organization_membership, user: foreign_user, organization: other)
      create(:user_role, user: foreign_user, system_role: role, organization: other)

      patch permissions_system_role_path(role), params: { permission_ids: [access.id] }
      expect(response).to have_http_status(:forbidden)
      expect(role.permissions.reload).to be_empty
      get system_role_path(role)
      expect(Nokogiri::HTML(response.body).at_css('[data-permissions-mode="view"]')).to be_present
    end

    it 'keeps a legacy soft-deleted role read-only even when its status is active' do
      legacy = create(:system_role, :system, :deleted)

      patch permissions_system_role_path(legacy), params: { permission_ids: [access.id] }
      expect(response).to have_http_status(:forbidden)
      expect(legacy.permissions.reload).to be_empty
      get system_role_path(legacy)
      expect(Nokogiri::HTML(response.body).at_css('[data-permissions-mode="view"]')).to be_present
    end

    it 'preserves permissions and editable workspace after an invalid permission selection' do
      patch permissions_system_role_path(role), params: { permission_ids: [action.id] }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('[data-permissions-mode="edit"] #system_role_permission_ids_error')).to be_present
      expect(role.permissions.reload).to be_empty
    end
  end
end
