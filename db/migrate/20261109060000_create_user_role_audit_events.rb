# frozen_string_literal: true

class CreateUserRoleAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :user_role_audit_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :system_role, null: false, foreign_key: true
      t.references :branch, foreign_key: true
      t.string :action, null: false, limit: 16
      t.datetime :deleted_at
      t.timestamps

      t.index %i[organization_id user_id created_at], name: 'idx_user_role_audits_tenant_history'
      t.index %i[user_id action created_at], name: 'idx_user_role_audits_action_history'
      t.check_constraint "action IN ('granted', 'revoked')", name: 'chk_user_role_audits_action'
    end
  end
end
