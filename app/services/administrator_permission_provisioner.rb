# frozen_string_literal: true

class AdministratorPermissionProvisioner
  def self.call(role:)
    new(role).call
  end

  def initialize(role)
    @role = role
  end

  def call
    Permission.available.find_each do |permission|
      SystemRolePermission.find_or_create_by!(system_role: @role, permission:)
    end
    @role
  end
end