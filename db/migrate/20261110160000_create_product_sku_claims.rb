# frozen_string_literal: true

class CreateProductSkuClaims < ActiveRecord::Migration[8.1]
  def up
    create_table :product_sku_claims do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :normalized_sku, limit: 50, null: false
      t.string :owner_type, limit: 50, null: false
      t.bigint :owner_id, null: false
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :product_sku_claims, %i[organization_id normalized_sku], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_product_sku_claim_unique'
    add_index :product_sku_claims, %i[owner_type owner_id], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_product_sku_claim_owner'

    existing_conflict = select_value(<<~SQL)
      SELECT p.sku FROM products p
      INNER JOIN product_variants v
        ON v.organization_id = p.organization_id AND lower(v.sku) = lower(p.sku)
      WHERE p.deleted_at IS NULL AND v.deleted_at IS NULL
        AND p.sku IS NOT NULL AND v.sku IS NOT NULL
      LIMIT 1
    SQL
    if existing_conflict
      raise ActiveRecord::MigrationError, "Resolve existing product/variant SKU conflict before migration: #{existing_conflict}"
    end

    execute <<~SQL
      INSERT INTO product_sku_claims (organization_id, normalized_sku, owner_type, owner_id, created_at, updated_at)
      SELECT organization_id, lower(sku), 'Product', id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM products WHERE deleted_at IS NULL AND sku IS NOT NULL AND btrim(sku) <> ''
    SQL
    execute <<~SQL
      INSERT INTO product_sku_claims (organization_id, normalized_sku, owner_type, owner_id, created_at, updated_at)
      SELECT organization_id, lower(sku), 'ProductVariant', id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM product_variants WHERE deleted_at IS NULL AND sku IS NOT NULL AND btrim(sku) <> ''
    SQL
  end

  def down
    drop_table :product_sku_claims
  end
end
