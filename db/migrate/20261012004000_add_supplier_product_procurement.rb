# frozen_string_literal: true

class AddSupplierProductProcurement < ActiveRecord::Migration[8.1]
  def change
    add_reference :products, :organization, foreign_key: true, null: true, index: true

    create_table :supplier_products do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.string :supplier_sku, limit: 80
      t.string :supplier_barcode, limit: 80
      t.string :presentation_name, null: false, limit: 80, default: 'Unit'
      t.decimal :units_per_package, null: false, precision: 14, scale: 4, default: 1
      t.decimal :purchase_price, null: false, precision: 14, scale: 4, default: 0
      t.decimal :discount_percent, null: false, precision: 6, scale: 3, default: 0
      t.decimal :freight_amount, null: false, precision: 14, scale: 4, default: 0
      t.decimal :nonrecoverable_tax, null: false, precision: 14, scale: 4, default: 0
      t.decimal :minimum_quantity, null: false, precision: 14, scale: 4, default: 1
      t.integer :lead_time_days, null: false, default: 0
      t.boolean :preferred, null: false, default: false
      t.boolean :active, null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :supplier_products, %i[organization_id supplier_id product_id presentation_name],
              unique: true, where: 'deleted_at IS NULL', name: 'idx_supplier_products_active_pair'
    add_index :supplier_products, %i[organization_id product_id],
              unique: true, where: 'preferred = TRUE AND deleted_at IS NULL',
              name: 'idx_supplier_products_one_preferred'

    create_table :supplier_product_prices do |t|
      t.references :supplier_product, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.decimal :purchase_price, precision: 14, scale: 4, null: false
      t.string :presentation_name, null: false, limit: 80
      t.decimal :units_per_package, precision: 14, scale: 4, null: false
      t.decimal :discount_percent, precision: 6, scale: 3, null: false, default: 0
      t.decimal :freight_amount, precision: 14, scale: 4, null: false, default: 0
      t.decimal :nonrecoverable_tax, precision: 14, scale: 4, null: false, default: 0
      t.date :effective_on, null: false
      t.datetime :deleted_at
      t.datetime :created_at, null: false
    end
    add_index :supplier_product_prices, %i[supplier_product_id effective_on created_at],
              name: 'idx_supplier_prices_history'
    add_check_constraint :supplier_products, 'units_per_package > 0', name: 'chk_supplier_product_factor'
    add_check_constraint :supplier_products, 'purchase_price >= 0 AND freight_amount >= 0 AND nonrecoverable_tax >= 0',
                         name: 'chk_supplier_product_costs'
    add_check_constraint :supplier_products, 'discount_percent BETWEEN 0 AND 100',
                         name: 'chk_supplier_product_discount'
    add_check_constraint :supplier_product_prices, 'units_per_package > 0 AND purchase_price >= 0',
                         name: 'chk_supplier_history_values'
  end
end
