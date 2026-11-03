# frozen_string_literal: true

class AddGranularUserStatusPermissions < ActiveRecord::Migration[8.1]
  def up
    permissions = %w[invite resend_invitation suspend reactivate block unblock destroy restore]
    permissions.each do |action|
      code = "users.#{action}"
      execute <<~SQL.squish
        INSERT INTO permissions (code, name, module_name, description, status, created_at, updated_at)
        VALUES (#{connection.quote(code)}, #{connection.quote("Manage user #{action}")},
                'Usuarios', 'Account status administration', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (code) DO NOTHING
      SQL
    end

    execute <<~SQL.squish
      INSERT INTO system_role_permissions (system_role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM system_roles roles CROSS JOIN permissions
      WHERE roles.code IN ('administrator', 'super_admin')
        AND roles.deleted_at IS NULL
        AND permissions.code IN (#{permissions.map { |p| connection.quote("users.#{p}") }.join(', ')})
      ON CONFLICT (system_role_id, permission_id) DO NOTHING
    SQL
  end

  def down
    # Do not revoke existing assignments or delete permissions used by audit history.
  end
end
