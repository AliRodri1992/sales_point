# frozen_string_literal: true

class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :first_name, null: false, limit: 80
      t.string :last_name, null: false, limit: 120
      t.string :email, null: false
      t.string :phone, limit: 30
      t.string :status, null: false, default: 'active', limit: 20
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :employees, :deleted_at

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX idx_employees_org_email_active
          ON employees (organization_id, LOWER(email))
          WHERE deleted_at IS NULL
        SQL
      end

      dir.down do
        execute 'DROP INDEX IF EXISTS idx_employees_org_email_active'
      end
    end

    add_check_constraint :employees,
                         "status IN ('active', 'inactive', 'terminated')",
                         name: 'check_employees_status'
  end
end
