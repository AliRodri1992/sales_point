# frozen_string_literal: true

class CreateSupplierEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_events do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :title, null: false, limit: 150
      t.string :kind, null: false
      t.timestamp :starts_at, null: false
      t.timestamp :ends_at
      t.text :notes
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :supplier_events, %i[supplier_id starts_at], name: 'idx_supplier_events_by_date'
    add_index :supplier_events, :deleted_at
  end
end
