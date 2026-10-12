# frozen_string_literal: true

class CreateBranchInventories < ActiveRecord::Migration[8.1]
  def change
    create_table :inventories do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :stock, precision: 14, scale: 3, null: false, default: 0
      t.decimal :min_stock, precision: 14, scale: 3, null: false, default: 0
      t.decimal :max_stock, precision: 14, scale: 3
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :inventories, %i[branch_id product_id], unique: true
    add_check_constraint :inventories, 'stock >= 0 AND min_stock >= 0',
                         name: 'chk_inventory_nonnegative'
    add_check_constraint :inventories, 'max_stock IS NULL OR max_stock >= min_stock',
                         name: 'chk_inventory_limits'

    create_table :inventory_movements do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :inventory, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :kind, null: false, limit: 24
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.decimal :stock_before, precision: 14, scale: 3, null: false
      t.decimal :stock_after, precision: 14, scale: 3, null: false
      t.string :reference, limit: 100
      t.datetime :deleted_at
      t.timestamps
    end

    add_check_constraint :inventory_movements, 'quantity <> 0', name: 'chk_movement_nonzero'
    add_index :inventory_movements, %i[inventory_id created_at]
    remove_column :products, :stock, :decimal
    remove_column :products, :min_stock, :decimal
    remove_column :products, :max_stock, :decimal
  end
end
