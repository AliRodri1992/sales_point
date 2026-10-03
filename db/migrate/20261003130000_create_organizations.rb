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
    add_index :organizations, 'LOWER(tax_id)', unique: true, where: 'deleted_at IS NULL',
              name: 'idx_organizations_tax_id_active'
    add_check_constraint :organizations,
                         "status IN ('active', 'inactive', 'suspended')",
                         name: 'check_organizations_status'
  end
end