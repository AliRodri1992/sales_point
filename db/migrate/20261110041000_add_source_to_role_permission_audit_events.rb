# frozen_string_literal: true

class AddSourceToRolePermissionAuditEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :system_role_permission_audit_events, :source, :string, null: false, default: 'user'
    change_column_null :system_role_permission_audit_events, :actor_id, true
    add_check_constraint :system_role_permission_audit_events,
                         "(source = 'user' AND actor_id IS NOT NULL) OR (source = 'system' AND actor_id IS NULL)",
                         name: 'chk_role_permission_audit_source_actor'
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'System-origin audit events cannot be assigned to an actor'
  end
end
