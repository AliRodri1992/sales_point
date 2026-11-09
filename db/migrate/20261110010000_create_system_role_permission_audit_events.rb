# frozen_string_literal: true

class CreateSystemRolePermissionAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :system_role_permission_audit_events do |t|
      t.references :system_role, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.jsonb :added_permission_codes, null: false, default: []
      t.jsonb :removed_permission_codes, null: false, default: []
      t.timestamp :created_at, null: false
      t.timestamp :deleted_at

      t.index %i[system_role_id created_at], name: 'idx_role_permission_audits_role_history'
    end
  end
