# frozen_string_literal: true

class CreatePurchaseEventDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_event_deliveries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.string :event_key, limit: 64, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :purchase_event_deliveries, :event_key, unique: true
  end
end
