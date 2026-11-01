# frozen_string_literal: true

class CreatePurchaseReceivingTraceability < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :tracking_mode, :string, null: false, default: 'none'
    add_check_constraint :products, "tracking_mode IN ('none', 'lot', 'serial')",
                         name: 'chk_products_tracking_mode'

    create_table :goods_receipts do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :purchase_order, null: false, foreign_key: true
      t.references :received_by, null: false, foreign_key: { to_table: :users }
      t.string :idempotency_key, null: false, limit: 100
      t.string :status, null: false, default: 'posted'
      t.text :notes
      t.datetime :received_at, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :goods_receipts, %i[organization_id idempotency_key], unique: true,
              name: 'idx_goods_receipts_idempotent'

    create_table :goods_receipt_items do |t|
      t.references :goods_receipt, null: false, foreign_key: true
      t.references :purchase_order_item, null: false, foreign_key: true
      t.decimal :delivered_quantity, precision: 14, scale: 3, null: false
      t.decimal :accepted_quantity, precision: 14, scale: 3, null: false
      t.decimal :damaged_quantity, precision: 14, scale: 3, null: false, default: 0
      t.string :lot_code, limit: 100
      t.date :expires_on
      t.decimal :landed_unit_cost, precision: 18, scale: 6, null: false, default: 0
      t.text :notes
      t.datetime :deleted_at
      t.timestamps
    end
    add_check_constraint :goods_receipt_items,
                         'delivered_quantity >= 0 AND accepted_quantity >= 0 AND damaged_quantity >= 0 AND ' \
                         'accepted_quantity + damaged_quantity <= delivered_quantity',
                         name: 'chk_receipt_item_differences'

    create_table :inventory_lots do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :inventory, null: false, foreign_key: true
      t.references :goods_receipt_item, foreign_key: true
      t.string :code, null: false, limit: 100
      t.date :expires_on
      t.string :status, null: false, default: 'available'
      t.decimal :quantity, precision: 14, scale: 3, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :inventory_lots, %i[inventory_id code], unique: true, where: 'deleted_at IS NULL'
    add_check_constraint :inventory_lots, 'quantity >= 0', name: 'chk_inventory_lot_quantity'

    create_table :inventory_serials do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :inventory_lot, null: false, foreign_key: true
      t.string :serial_number, null: false
      t.string :status, null: false, default: 'available'
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :inventory_serials, %i[organization_id serial_number],
              unique: true, where: 'deleted_at IS NULL', name: 'idx_inventory_serials_unique'

    create_table :purchase_returns do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :goods_receipt, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'draft'
      t.string :reason, null: false, default: 'damaged'
      t.text :notes
      t.datetime :processed_at
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :purchase_return_items do |t|
      t.references :purchase_return, null: false, foreign_key: true
      t.references :goods_receipt_item, null: false, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.text :notes
      t.datetime :deleted_at
      t.timestamps
    end
    add_check_constraint :purchase_return_items, 'quantity > 0',
                         name: 'chk_purchase_return_positive'

    add_reference :inventory_movements, :source, polymorphic: true, index: true
    add_reference :inventory_movements, :inventory_lot, foreign_key: true

    create_table :purchase_cost_allocations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :goods_receipt_item, null: false, foreign_key: true
      t.decimal :goods_amount, precision: 18, scale: 6, null: false
      t.decimal :freight_amount, precision: 18, scale: 6, null: false
      t.decimal :insurance_amount, precision: 18, scale: 6, null: false
      t.decimal :landed_unit_cost, precision: 18, scale: 6, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :purchase_cost_allocations, :goods_receipt_item_id,
              unique: true, name: 'idx_purchase_cost_allocation_receipt_item'
  end
end
