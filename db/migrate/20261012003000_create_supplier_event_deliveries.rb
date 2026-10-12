# frozen_string_literal: true

class CreateSupplierEventDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_event_deliveries do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.string :event_key, null: false, limit: 64
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :supplier_event_deliveries, :event_key, unique: true
  end
end
