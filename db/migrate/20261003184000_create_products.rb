# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, default: 0, null: false
      t.decimal :cost, precision: 12, scale: 2, default: 0, null: false
      t.string :barcode
      t.string :sku
      t.references :category, null: true, foreign_key: true
      t.references :sat_unit_key, null: true, foreign_key: true
      t.references :sat_tax, null: true, foreign_key: true
      t.string :status, default: 'active', null: false
      t.timestamp :deleted_at

      t.timestamps
    end

    add_index :products, %i[organization_id code], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_products_org_code'
    add_index :products, %i[organization_id sku], unique: true,
              where: 'deleted_at IS NULL AND sku IS NOT NULL', name: 'idx_products_org_sku'
    add_index :products, :barcode, where: '(deleted_at IS NULL)'
    add_index :products, :deleted_at
  end
end
