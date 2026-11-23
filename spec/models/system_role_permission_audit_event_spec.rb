# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolePermissionAuditEvent, type: :model do
  let(:role) { create(:system_role, :system) }

  it 'requires an actor for user changes and forbids attributing system changes to a user' do
    user_event = role.permission_audit_events.build(source: 'user', added_permission_codes: ['products.show'])
    system_event = role.permission_audit_events.build(source: 'system', actor: create(:user),
                                                     removed_permission_codes: ['products.show'])
    [user_event, system_event].each do |event|
      expect(event).to be_invalid
      expect(event.errors.of_kind?(:source, :invalid)).to be(true)
    end
  end

  it 'rejects empty audit events and accepts removal-only system events' do
    event = role.permission_audit_events.build(source: 'system')
    expect(event).to be_invalid
    expect(event.errors.of_kind?(:base, :invalid)).to be(true)
    event.removed_permission_codes = ['products.show']
    expect(event).to be_valid
  end
end
