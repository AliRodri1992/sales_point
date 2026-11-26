# frozen_string_literal: true

# Backfill the dedicated New Role permission for both administrative profiles.
# This file is safe to load independently or through db/seeds.rb.
module RoleCreationPermissionSeeds
  PERMISSION_CODE = 'roles.create'.freeze

  def self.seed!
    permission = Permission.find_or_initialize_by(code: PERMISSION_CODE)
    permission.assign_attributes(
      name: 'Crear roles',
      module_name: 'Roles',
      description: 'Permite crear roles inactivos para configurar sus permisos posteriormente.',
      status: :active
    )
    permission.save! if permission.new_record? || permission.changed?

    SystemRole.available.system_roles.where(code: SystemRole::ADMINISTRATIVE_CODES).find_each do |role|
      AdministratorPermissionProvisioner.call(role:)
    end

    permission
  end
end
