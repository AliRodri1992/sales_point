# frozen_string_literal: true

class ScopeActiveProductBarcodes < ActiveRecord::Migration[8.1]
  def change
    remove_index :product_barcodes, [:organization_id, :value], unique: true
    add_index :product_barcodes, [:organization_id, :value], unique: true, where: 'deleted_at IS NULL'
  end
end
