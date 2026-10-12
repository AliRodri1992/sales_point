# frozen_string_literal: true

class ScopeProductIdentifiersToOrganization < ActiveRecord::Migration[8.1]
  def change
    remove_index :products, :code
    remove_index :products, :sku
    remove_index :products, :slug
    add_index :products, %i[organization_id code], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_products_org_code'
    add_index :products, %i[organization_id sku], unique: true,
              where: 'deleted_at IS NULL AND sku IS NOT NULL', name: 'idx_products_org_sku'
    add_index :products, %i[organization_id slug], unique: true,
              where: 'deleted_at IS NULL AND slug IS NOT NULL', name: 'idx_products_org_slug'
    change_column_null :products, :organization_id, false
  end
end
