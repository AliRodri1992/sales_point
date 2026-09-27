# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, default: 0, null: false
      t.decimal :cost, precision: 12, scale: 2, default: 0, null: false
      t.decimal :stock, precision: 10, scale: 3, default: 0, null: false
      t.decimal :min_stock, precision: 10, scale: 3, default: 0, null: false
      t.decimal :max_stock, precision: 10, scale: 3
      t.string :barcode
      t.string :sku
      t.references :category, null: true, foreign_key: true
      t.references :sat_unit_key, null: true, foreign_key: true
      t.references :sat_tax, null: true, foreign_key: true
      t.string :status, default: 'active', null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :products, :code, unique: true, where: '(deleted_at IS NULL)'
    add_index :products, :sku, unique: true, where: '(deleted_at IS NULL)'
    add_index :products, :barcode, where: '(deleted_at IS NULL)'
    add_index :products, :deleted_at
  end
end
