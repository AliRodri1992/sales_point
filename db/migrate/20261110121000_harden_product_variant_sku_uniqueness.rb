# frozen_string_literal: true

class HardenProductVariantSkuUniqueness < ActiveRecord::Migration[8.1]
  def change
    remove_index :product_variants, name: 'index_product_variants_on_organization_id_and_sku'
    add_index :product_variants, 'organization_id, LOWER(sku)',
              unique: true,
              where: "deleted_at IS NULL AND sku IS NOT NULL AND sku <> ''",
              name: 'idx_product_variants_org_sku_ci'
  end
end
