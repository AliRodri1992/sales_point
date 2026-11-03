# frozen_string_literal: true

class CreateUserSecurityIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :user_security_incidents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :opened_by, null: false, foreign_key: { to_table: :users }
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.text :description, null: false
      t.text :resolution
      t.datetime :resolved_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :user_security_incidents, [:organization_id, :user_id, :resolved_at],
              name: 'idx_user_incidents_tenant_review'
  end
end
