# frozen_string_literal: true

namespace :permissions do
  desc 'Backfill every active permission for administrator and super_admin roles'
  task sync_administrators: :environment do
    roles = SystemRole.available.active.system_roles
                      .where(code: SystemRole::ADMINISTRATIVE_CODES)

    roles.find_each do |role|
      AdministratorPermissionProvisioner.call(role:)
      puts "#{role.code}: #{role.permissions.available.count} active permissions"
    end
  end
end
