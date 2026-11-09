# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdministratorPermissionProvisioner do
  let!(:super_role) { create(:system_role, :system, code: 'super_admin') }
  let!(:admin_role) { create(:system_role, :system, code: 'administrator') }

  it 'records automatic provisioning with a system source, never a forged actor' do
    permission = create(:permission, code: 'auto_audit.grant')
    [super_role, admin_role].each do |role|
      expect(role.permissions.reload).to include(permission)
      event = role.permission_audit_events.last
      expect(event.source).to eq('system')
      expect(event.actor).to be_nil
      expect(event.added_permission_codes).to include(permission.code)
      expect(event.removed_permission_codes).to be_empty
    end
  end

  it 'does not create another audit when an already-provisioned role is synchronized' do
    permission = create(:permission, code: 'auto_audit.existing')
    expect do
      described_class.call_for_permission(permission:)
      described_class.call(role: super_role)
    end.not_to change(SystemRolePermissionAuditEvent, :count)
  end
end
