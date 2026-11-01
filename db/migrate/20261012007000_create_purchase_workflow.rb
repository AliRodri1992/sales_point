# frozen_string_literal: true

class CreatePurchaseWorkflow < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_requests do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :code, null: false
      t.string :status, null: false, default: 'draft'
      t.date :needed_on
      t.text :notes
      t.datetime :submitted_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :purchase_requests, %i[organization_id code], unique: true

    create_table :purchase_request_items do |t|
      t.references :purchase_request, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.text :notes
      t.datetime :deleted_at
      t.timestamps
    end
    add_check_constraint :purchase_request_items, 'quantity > 0', name: 'chk_purchase_request_quantity'

    create_table :purchase_quotations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :purchase_request, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.string :code, null: false
      t.string :status, null: false, default: 'draft'
      t.date :valid_until
      t.text :notes
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :purchase_quotations, %i[organization_id code], unique: true

    create_table :purchase_quotation_items do |t|
      t.references :purchase_quotation, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :supplier_product, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.decimal :units_per_package, precision: 14, scale: 4, null: false, default: 1
      t.decimal :unit_price, precision: 14, scale: 4, null: false
      t.decimal :discount_percent, precision: 6, scale: 3, null: false, default: 0
      t.integer :lead_time_days, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :purchase_orders do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.references :purchase_request, foreign_key: true
      t.references :purchase_quotation, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.string :code, null: false
      t.string :status, null: false, default: 'draft'
      t.decimal :freight_amount, precision: 14, scale: 4, null: false, default: 0
      t.decimal :insurance_amount, precision: 14, scale: 4, null: false, default: 0
      t.decimal :exchange_rate, precision: 18, scale: 8, null: false, default: 1
      t.date :expected_on
      t.text :notes
      t.datetime :approved_at
      t.datetime :cancelled_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :purchase_orders, %i[organization_id code], unique: true

    create_table :purchase_order_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :supplier_product, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.decimal :units_per_package, precision: 14, scale: 4, null: false, default: 1
      t.decimal :unit_price, precision: 14, scale: 4, null: false
      t.decimal :discount_percent, precision: 6, scale: 3, null: false, default: 0
      t.decimal :nonrecoverable_tax, precision: 14, scale: 4, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :purchase_approvals do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :purchase_order, null: false, foreign_key: true
      t.references :decided_by, null: false, foreign_key: { to_table: :users }
      t.string :decision, null: false
      t.text :notes
      t.datetime :deleted_at
      t.timestamps
    end

    %i[purchase_quotation_items purchase_order_items].each do |table|
      add_check_constraint table, 'quantity > 0 AND units_per_package > 0 AND unit_price >= 0',
                           name: "chk_#{table}_quantities"
      add_check_constraint table, 'discount_percent BETWEEN 0 AND 100',
                           name: "chk_#{table}_discount"
    end
    add_check_constraint :purchase_orders,
                         'freight_amount >= 0 AND insurance_amount >= 0 AND exchange_rate > 0',
                         name: 'chk_purchase_order_expenses'
  end
end
