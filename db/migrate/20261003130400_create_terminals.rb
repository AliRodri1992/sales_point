# frozen_string_literal: true

class CreateTerminals < ActiveRecord::Migration[8.1]
  def change
    create_table :terminals do |t|
      t.references :branch, null: false, foreign_key: true
      t.string :name, null: false, limit: 80
      t.string :code, null: false, limit: 40
      t.string :status, null: false, default: 'active', limit: 20
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :terminals, :deleted_at
    add_index :terminals, [:branch_id, 'LOWER(code)'], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_terminals_branch_code_active'
    add_check_constraint :terminals,
                         "status IN ('active', 'inactive')",
                         name: 'check_terminals_status'
  end
end