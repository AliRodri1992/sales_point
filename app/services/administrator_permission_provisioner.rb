# frozen_string_literal: true

class AdministratorPermissionProvisioner
  def self.call(role:)
    new(role).call
  end

  # Synchronize new and reactivated permissions without requiring another seed run.
  def self.call_for_permission(permission:)
    return unless permission.active?

    SystemRole.available.active.system_roles
              .where(code: SystemRole::ADMINISTRATIVE_CODES).find_each do |role|
      SystemRolePermission.find_or_create_by!(system_role: role, permission: permission)
    end
  end

  def initialize(role)
    @role = role
  end

  def call
    Permission.available.find_each do |permission|
      SystemRolePermission.find_or_create_by!(
        system_role: @role,
        permission:
      )
    end

    @role
  end
end
