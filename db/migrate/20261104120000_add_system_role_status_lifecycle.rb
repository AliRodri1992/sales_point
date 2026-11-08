# frozen_string_literal: true

class AddSystemRoleStatusLifecycle < ActiveRecord::Migration[8.1]
  def change
    change_column_default :system_roles, :status, from: 'active', to: 'inactive'
    create_table :system_role_status_events do |t|
      t.references :system_role, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.text :reason, null: false
      t.jsonb :impact, null: false, default: {}
      t.timestamp :created_at, null: false
      t.timestamp :deleted_at
      t.index %i[system_role_id created_at], name: 'index_role_status_events_on_role_and_created_at'
    end
  end
end
