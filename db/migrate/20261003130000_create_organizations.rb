# frozen_string_literal: true

class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false, limit: 150
      t.string :tax_id, null: false, limit: 13
      t.string :business_sector, null: false, limit: 50
      t.string :status, null: false, default: 'active', limit: 20
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :organizations, :deleted_at

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX idx_organizations_tax_id_active
          ON organizations (LOWER(tax_id))
          WHERE deleted_at IS NULL
        SQL
      end

      dir.down do
        execute 'DROP INDEX IF EXISTS idx_organizations_tax_id_active'
      end
    end

    add_check_constraint :organizations,
                         "status IN ('active', 'inactive', 'suspended')",
                         name: 'check_organizations_status'
  end
end
