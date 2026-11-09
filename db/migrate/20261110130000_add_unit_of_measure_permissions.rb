# frozen_string_literal: true

class AddUnitOfMeasurePermissions < ActiveRecord::Migration[8.1]
  ACTIONS = %w[access index show create update destroy].freeze

  def up
    ACTIONS.each do |action|
      code = "units_of_measure.#{action}"
      execute <<~SQL.squish
        INSERT INTO permissions (code, name, module_name, description, status, created_at, updated_at)
        VALUES (#{connection.quote(code)}, #{connection.quote("#{action.humanize} Unidades de medida")},
                'Unidades de medida', #{connection.quote("#{action.humanize}: Unidades de medida")},
                'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (code) DO NOTHING
      SQL
    end

    execute <<~SQL.squish
      INSERT INTO system_role_permissions (system_role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM system_roles roles CROSS JOIN permissions
      WHERE roles.code IN ('administrator', 'super_admin')
        AND roles.role_type = 'system' AND roles.status = 'active' AND roles.deleted_at IS NULL
        AND permissions.code IN (#{ACTIONS.map { |action| connection.quote("units_of_measure.#{action}") }.join(', ')})
        AND permissions.status = 'active' AND permissions.deleted_at IS NULL
      ON CONFLICT (system_role_id, permission_id) DO NOTHING
    SQL
  end

  def down
    # Preserve permissions and their audit history.
  end
end
