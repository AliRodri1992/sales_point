# frozen_string_literal: true

class AddGranularCatalogPermissions < ActiveRecord::Migration[8.1]
  MODULES = {
    'languages' => 'Idiomas', 'products' => 'Productos', 'customers' => 'Clientes',
    'users' => 'Usuarios', 'categories' => 'Categorías'
  }.freeze
  ACTIONS = %w[access index show create update destroy].freeze

  def up
    MODULES.each do |prefix, label|
      ACTIONS.each { |action| create_permission(prefix, label, action) }
      migrate_legacy_assignments(prefix)
    end
    provision_administrators
  end

  def down
    # Preserve assignments and administrator access when rolling back application code.
  end

  private

  def create_permission(prefix, label, action)
    execute <<~SQL.squish
      INSERT INTO permissions (code, name, module_name, description, status, created_at, updated_at)
      VALUES (#{connection.quote("#{prefix}.#{action}")}, #{connection.quote("#{action.humanize} #{label}")},
              #{connection.quote(label)}, #{connection.quote("#{action.humanize}: #{label}")},
              'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (code) DO NOTHING
    SQL
  end

  def migrate_legacy_assignments(prefix)
    execute <<~SQL.squish
      INSERT INTO system_role_permissions (system_role_id, permission_id, created_at, updated_at)
      SELECT legacy.system_role_id, granular.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM system_role_permissions legacy
      JOIN permissions access ON access.id = legacy.permission_id
      JOIN system_roles roles ON roles.id = legacy.system_role_id
      CROSS JOIN permissions granular
      WHERE access.code = #{connection.quote("#{prefix}.access")}
        AND access.status = 'active' AND access.deleted_at IS NULL AND legacy.deleted_at IS NULL
        AND roles.deleted_at IS NULL AND roles.status != 'deprecated'
        AND granular.code IN (#{ACTIONS.drop(1).map { |action| connection.quote("#{prefix}.#{action}") }.join(', ')})
        AND granular.status = 'active' AND granular.deleted_at IS NULL
      ON CONFLICT (system_role_id, permission_id) DO NOTHING
    SQL
  end

  def provision_administrators
    execute <<~SQL.squish
      INSERT INTO system_role_permissions (system_role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM system_roles roles CROSS JOIN permissions
      WHERE roles.code IN ('administrator', 'super_admin') AND roles.role_type = 'system'
        AND roles.deleted_at IS NULL AND roles.status = 'active'
        AND permissions.deleted_at IS NULL AND permissions.status = 'active'
        AND permissions.code IN (#{MODULES.keys.product(ACTIONS).map { |parts| connection.quote(parts.join('.')) }.join(', ')})
      ON CONFLICT (system_role_id, permission_id) DO NOTHING
    SQL
  end
end
