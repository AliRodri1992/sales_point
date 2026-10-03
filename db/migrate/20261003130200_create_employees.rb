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
    add_index :employees, [:organization_id, 'LOWER(email)'], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_employees_org_email_active'
    add_check_constraint :employees,
                         "status IN ('active', 'inactive', 'terminated')",
                         name: 'check_employees_status'
  end
end