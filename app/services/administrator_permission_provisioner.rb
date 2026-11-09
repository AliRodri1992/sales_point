# frozen_string_literal: true

class AdministratorPermissionProvisioner
  def self.call(role:)
    new(role).call
  end

  # New permissions are granted to the two protected roles with a durable
  # system-origin audit entry. The audit and assignment share one transaction.
  def self.call_for_permission(permission:)
    return unless permission.active?

    SystemRole.available.active.system_roles
              .where(code: SystemRole::ADMINISTRATIVE_CODES).find_each do |role|
      role.with_lock do
        next if role.system_role_permissions.exists?(permission_id: permission.id)

        role.system_role_permissions.create!(permission:)
        role.permission_audit_events.create!(
          source: 'system', added_permission_codes: [permission.code], removed_permission_codes: []
        )
      end
    end
  end

  def initialize(role)
    @role = role
  end

  def call
    @role.with_lock do
      missing = Permission.available.where.not(
        id: @role.system_role_permissions.select(:permission_id)
      ).to_a

      if missing.any?
        missing.each { |permission| @role.system_role_permissions.create!(permission:) }
        @role.permission_audit_events.create!(
          source: 'system', added_permission_codes: missing.map(&:code).sort, removed_permission_codes: []
        )
      end
    end
    @role
  end
end
