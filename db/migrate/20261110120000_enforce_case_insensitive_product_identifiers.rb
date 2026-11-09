# frozen_string_literal: true

class EnforceCaseInsensitiveProductIdentifiers < ActiveRecord::Migration[8.1]
  def change
    add_index :products, 'organization_id, LOWER(code)',
              unique: true, where: 'deleted_at IS NULL', name: 'idx_products_org_code_ci'
    add_index :products, 'organization_id, LOWER(sku)',
              unique: true, where: 'deleted_at IS NULL AND sku IS NOT NULL',
              name: 'idx_products_org_sku_ci'
    add_index :product_barcodes, 'organization_id, LOWER(value)',
              unique: true, where: 'deleted_at IS NULL', name: 'idx_product_barcodes_org_value_ci'
  end
end
