# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/role_creation_permissions')

RSpec.describe RoleCreationPermissionSeeds, type: :model do
  let!(:administrator) { create(:system_role, :system, code: 'administrator') }
  let!(:superadministrator) { create(:system_role, :system, code: 'super_admin') }
  let!(:cashier) { create(:system_role, :system, code: 'cashier') }

  it 'provisions the New Role permission to both administrative roles only, without duplicates' do
    permission = described_class.seed!

    expect(permission).to have_attributes(
      code: 'roles.create', module_name: 'Roles', status: 'active'
    )
    expect(Permission.where(code: 'roles.create').count).to eq(1)
    [administrator, superadministrator].each do |role|
      expect(role.permissions).to include(permission)
    end
    expect(cashier.permissions).not_to include(permission)

    grants = SystemRolePermission.where(permission:)
    initial_ids = grants.order(:id).pluck(:id)
    audit_count = SystemRolePermissionAuditEvent.count

    described_class.seed!

    expect(grants.order(:id).pluck(:id)).to eq(initial_ids)
    expect(SystemRolePermissionAuditEvent.count).to eq(audit_count)
  end

  it 'restores a removed administrative assignment on a later run' do
    permission = described_class.seed!
    administrator.system_role_permissions.where(permission:).delete_all

    described_class.seed!

    expect(administrator.permissions.where(id: permission.id).count).to eq(1)
    expect(superadministrator.permissions.where(id: permission.id).count).to eq(1)
  end
end
