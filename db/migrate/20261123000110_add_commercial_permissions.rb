# frozen_string_literal: true

class AddCommercialPermissions < ActiveRecord::Migration[8.1]
  MODULES = { 'price_lists' => 'Listas de precios', 'promotions' => 'Promociones' }.freeze
  ACTIONS = %w[access index show create update archive activate pause resume duplicate history].freeze
  PRICE_LIST_ACTIONS = %w[view_margin authorize_below_cost].freeze

  def up
    codes = MODULES.flat_map do |prefix, label|
      actions = prefix == 'price_lists' ? ACTIONS + PRICE_LIST_ACTIONS : ACTIONS
      actions.map { |action| create_permission(prefix, label, action) }
    end
    grant_permissions(codes)
  end

  def down
    # Retain independent assignments and their audit history for a later re-deploy.
  end

  private

  def create_permission(prefix, label, action)
    code = "#{prefix}.#{action}"
    execute <<~SQL.squish
      INSERT INTO permissions (code, name, module_name, description, status, created_at, updated_at)
      VALUES (#{connection.quote(code)}, #{connection.quote("#{action.humanize} #{label}")},
              #{connection.quote(label)}, #{connection.quote("#{action.humanize}: #{label}")},
              'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (code) DO NOTHING
    SQL
    code
  end

  def grant_permissions(codes)
    execute <<~SQL.squish
      WITH legacy_readers AS (
        SELECT roles.id AS role_id, bool_or(permissions.code = 'products.show') AS can_show
        FROM system_roles roles
        JOIN system_role_permissions grants ON grants.system_role_id = roles.id AND grants.deleted_at IS NULL
        JOIN permissions ON permissions.id = grants.permission_id
        WHERE roles.deleted_at IS NULL AND roles.status IN ('active', 'inactive')
          AND permissions.code IN ('products.access', 'products.index', 'products.show')
          AND permissions.status = 'active' AND permissions.deleted_at IS NULL
        GROUP BY roles.id
        HAVING bool_or(permissions.code = 'products.access') AND bool_or(permissions.code = 'products.index')
      ), commercial_permissions AS (
        SELECT id, code, split_part(code, '.', 2) AS action
        FROM permissions
        WHERE code IN (#{codes.map { |code| connection.quote(code) }.join(', ')})
          AND deleted_at IS NULL AND status = 'active'
      ), eligible_grants AS (
        SELECT legacy_readers.role_id, commercial_permissions.id AS permission_id
        FROM legacy_readers CROSS JOIN commercial_permissions
        WHERE action IN ('access', 'index') OR (action = 'show' AND legacy_readers.can_show)
        UNION
        SELECT roles.id, commercial_permissions.id
        FROM system_roles roles CROSS JOIN commercial_permissions
        WHERE roles.code IN ('administrator', 'super_admin') AND roles.role_type = 'system'
          AND roles.deleted_at IS NULL AND roles.status = 'active'
      ), inserted AS (
        INSERT INTO system_role_permissions (system_role_id, permission_id, created_at, updated_at)
        SELECT role_id, permission_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM eligible_grants
        ON CONFLICT (system_role_id, permission_id) DO NOTHING
        RETURNING system_role_id, permission_id
      )
      INSERT INTO system_role_permission_audit_events
        (system_role_id, source, added_permission_codes, removed_permission_codes, created_at)
      SELECT inserted.system_role_id, 'system', jsonb_agg(permissions.code ORDER BY permissions.code),
             '[]'::jsonb, CURRENT_TIMESTAMP
      FROM inserted JOIN commercial_permissions permissions ON permissions.id = inserted.permission_id
      GROUP BY inserted.system_role_id
    SQL
  end
end
