# frozen_string_literal: true

class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.string :code, null: false, limit: 30
      t.string :name, null: false, limit: 150
      t.string :email, limit: 150
      t.string :phone, limit: 30
      t.string :rfc, limit: 13
      t.references :sat_fiscal_regime, foreign_key: true
      t.string :postal_code, limit: 5
      t.string :status, null: false, limit: 20, default: 'active'
      t.text :notes
      t.timestamp :deleted_at

      t.timestamps
    end

    add_index :suppliers, %i[organization_id code],
              unique: true, where: 'deleted_at IS NULL',
              name: 'idx_suppliers_organization_code_active'
    add_index :suppliers, %i[organization_id rfc],
              unique: true, where: "rfc IS NOT NULL AND rfc <> '' AND deleted_at IS NULL",
              name: 'idx_suppliers_organization_rfc_active'
    add_index :suppliers, %i[organization_id name],
              where: 'deleted_at IS NULL',
              name: 'idx_suppliers_org_name_active'
    add_index :suppliers, %i[organization_id status name],
              where: 'deleted_at IS NULL',
              name: 'idx_suppliers_org_status_name_active'
    add_index :suppliers, :email
    add_index :suppliers, :phone
    add_index :suppliers, :status
    add_index :suppliers, :deleted_at

    add_check_constraint :suppliers,
                         "code = BTRIM(code) AND code <> '' AND code ~ '^[A-Za-z0-9_-]+$'",
                         name: 'chk_suppliers_code_format'
    add_check_constraint :suppliers,
                         "name = BTRIM(name) AND name <> ''",
                         name: 'chk_suppliers_name_format'
    add_check_constraint :suppliers,
                         "rfc IS NULL OR rfc = '' OR rfc ~ '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'",
                         name: 'chk_suppliers_rfc_format'
    add_check_constraint :suppliers,
                         "postal_code IS NULL OR postal_code = '' OR postal_code ~ '^[0-9]{5}$'",
                         name: 'chk_suppliers_postal_code_format'
    add_check_constraint :suppliers,
                         "status IN ('active', 'inactive')",
                         name: 'chk_suppliers_status'
  end
end
