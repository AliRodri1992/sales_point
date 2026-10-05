# frozen_string_literal: true

class CreateOrganizationMigrations < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_migrations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :volume, null: false, limit: 20
      t.string :priority, null: false, limit: 20
      t.string :status, null: false, default: 'pending', limit: 20
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :organization_migrations, :deleted_at
    add_index :organization_migrations, :organization_id, unique: true,
              where: 'deleted_at IS NULL', name: 'idx_org_migrations_org_active'
    add_check_constraint :organization_migrations,
                         "volume IN ('under_500', '500_5000', 'over_5000')",
                         name: 'check_org_migrations_volume'
    add_check_constraint :organization_migrations,
                         "priority IN ('catalog', 'inventory', 'customers', 'all')",
                         name: 'check_org_migrations_priority'
    add_check_constraint :organization_migrations,
                         "status IN ('pending', 'in_progress', 'completed')",
                         name: 'check_org_migrations_status'
  end
end