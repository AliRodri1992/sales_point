# frozen_string_literal: true

class AddSupplierDossier < ActiveRecord::Migration[8.1]
  def change
    add_reference :suppliers, :responsible_user, foreign_key: { to_table: :users }
    add_column :suppliers, :tags, :text, array: true, default: [], null: false

    create_table :supplier_schedules do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :weekday, null: false
      t.time :starts_at, null: false
      t.time :ends_at
      t.text :notes
      t.timestamps
    end
    add_check_constraint :supplier_schedules, "kind IN ('visit', 'order', 'delivery')",
                         name: 'chk_supplier_schedules_kind'
    add_check_constraint :supplier_schedules, 'weekday BETWEEN 0 AND 6',
                         name: 'chk_supplier_schedules_weekday'
    add_index :supplier_schedules, %i[supplier_id branch_id kind weekday starts_at],
              unique: true, name: 'idx_supplier_schedules_unique_slot'
  end
end
