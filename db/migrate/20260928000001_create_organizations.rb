# frozen_string_literal: true

class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, limit: 150, null: false
      t.string :code, limit: 50, null: false
      t.string :legal_name, limit: 200
      t.string :tax_id, limit: 13
      t.string :email, limit: 150
      t.string :phone, limit: 30
      t.string :status, limit: 20, null: false, default: 'active'
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :organizations, :code, unique: true, where: 'deleted_at IS NULL'
    add_index :organizations, :tax_id, unique: true,
              where: "tax_id IS NOT NULL AND tax_id <> '' AND deleted_at IS NULL"
    add_index :organizations, :email
    add_index :organizations, :status
    add_index :organizations, :deleted_at

    add_check_constraint :organizations,
                         "btrim(name) <> ''",
                         name: 'chk_organizations_name_not_blank'
    add_check_constraint :organizations,
                         "code ~ '^[A-Za-z0-9_-]+  end
end
",
                         name: 'chk_organizations_code_format'
    add_check_constraint :organizations,
                         "status IN ('active', 'inactive')",
                         name: 'chk_organizations_status'
  end
end
