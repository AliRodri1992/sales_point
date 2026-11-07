# frozen_string_literal: true

class CreateProductCommercialCatalog < ActiveRecord::Migration[8.1]
  def change
    add_index :products, [:organization_id, :id], unique: true
    create_table :product_variants do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.string :sku, limit: 50
      t.jsonb :options, null: false, default: {}
      t.string :status, null: false, default: 'active'
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :product_variants, [:organization_id, :sku], unique: true, where: "sku IS NOT NULL AND sku <> ''"
    add_index :product_variants, [:organization_id, :product_id, :id], unique: true, name: 'idx_variant_tenant_product'
    create_table :product_presentations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.decimal :units, precision: 18, scale: 6, null: false, default: 1
      t.string :status, null: false, default: 'active'
      t.datetime :deleted_at
      t.timestamps
    end
    add_check_constraint :product_presentations, 'units > 0', name: 'presentation_positive_units'
    add_index :product_presentations, [:organization_id, :product_id, :id], unique: true, name: 'idx_presentation_tenant_product'
    create_table :product_barcodes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.references :product_presentation, foreign_key: true
      t.string :value, null: false, limit: 100
      t.string :symbology, null: false, default: 'code128'
      t.boolean :primary, null: false, default: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :product_barcodes, [:organization_id, :value], unique: true
    add_index :product_barcodes, :product_id, unique: true, where: '"primary" = true AND deleted_at IS NULL', name: 'idx_product_primary_barcode'
    create_table :price_lists do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.string :code, null: false, limit: 50
      t.string :currency, null: false, limit: 3, default: 'MXN'
      t.string :customer_segment, limit: 100
      t.string :status, null: false, default: 'draft'
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :price_lists, [:organization_id, :code], unique: true
    add_index :price_lists, [:organization_id, :id], unique: true
    add_check_constraint :price_lists, 'ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at', name: 'price_list_dates'
    create_table :price_list_items do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :price_list, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.references :product_presentation, foreign_key: true
      t.decimal :price, precision: 12, scale: 2, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :price_list_items, [:organization_id, :id], unique: true
    add_check_constraint :price_list_items, 'price >= 0', name: 'list_item_positive_price'
    add_check_constraint :price_list_items, 'ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at', name: 'price_item_dates'
    create_table :price_change_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :price_list_item, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.decimal :previous_price, precision: 12, scale: 2
      t.decimal :new_price, precision: 12, scale: 2, null: false
      t.string :currency, null: false, limit: 3
      t.string :status, null: false, default: 'pending'
      t.text :reason, null: false
      t.datetime :approved_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_check_constraint :price_change_events, 'new_price >= 0', name: 'price_change_positive_price'
    create_table :promotions do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.string :code, null: false, limit: 50
      t.string :currency, null: false, default: 'MXN', limit: 3
      t.string :status, null: false, default: 'draft'
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :usage_limit
      t.integer :customer_limit
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :promotions, [:organization_id, :code], unique: true
    add_index :promotions, [:organization_id, :id], unique: true
    add_check_constraint :promotions, 'ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at', name: 'promotion_dates'
    add_check_constraint :promotions, '(usage_limit IS NULL OR usage_limit > 0) AND (customer_limit IS NULL OR customer_limit > 0)', name: 'promotion_positive_limits'
    create_table :promotion_conditions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true
      t.string :kind, null: false
      t.references :product, foreign_key: true
      t.references :category, foreign_key: true
      t.decimal :quantity, precision: 18, scale: 6
      t.decimal :amount, precision: 12, scale: 2
      t.string :customer_segment, limit: 100
      t.datetime :deleted_at
      t.timestamps
    end
    create_table :promotion_benefits do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true
      t.string :kind, null: false, default: 'percentage'
      t.decimal :value, precision: 12, scale: 4, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_check_constraint :promotion_benefits, "value > 0 AND (kind <> 'percentage' OR value <= 100)", name: 'promotion_valid_benefit'
    create_table :promotion_redemptions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :idempotency_key, null: false, limit: 100
      t.string :customer_reference, limit: 100
      t.decimal :quantity, precision: 18, scale: 6, null: false
      t.decimal :discount, precision: 12, scale: 2, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :promotion_redemptions, [:organization_id, :idempotency_key], unique: true, name: 'idx_promotion_redemption_idempotency'
    add_index :promotion_redemptions, [:promotion_id, :customer_reference]
    add_check_constraint :promotion_redemptions, 'quantity > 0 AND discount >= 0', name: 'redemption_positive_values'
    %i[product_variants product_presentations product_barcodes price_list_items price_change_events promotion_redemptions].each do |table|
      add_foreign_key table, :products, column: [:organization_id, :product_id], primary_key: [:organization_id, :id]
    end
    %i[product_barcodes price_list_items].each do |table|
      add_foreign_key table, :product_variants, column: [:organization_id, :product_id, :product_variant_id], primary_key: [:organization_id, :product_id, :id]
      add_foreign_key table, :product_presentations, column: [:organization_id, :product_id, :product_presentation_id], primary_key: [:organization_id, :product_id, :id]
    end
    add_foreign_key :price_list_items, :price_lists, column: [:organization_id, :price_list_id], primary_key: [:organization_id, :id]
    %i[promotion_conditions promotion_benefits promotion_redemptions].each do |table|
      add_foreign_key table, :promotions, column: [:organization_id, :promotion_id], primary_key: [:organization_id, :id]
    end
    add_foreign_key :promotion_conditions, :products, column: [:organization_id, :product_id], primary_key: [:organization_id, :id]
    add_foreign_key :price_change_events, :price_list_items, column: [:organization_id, :price_list_item_id], primary_key: [:organization_id, :id]
    reversible do |direction|
      direction.up do
        execute <<~SQL
          INSERT INTO product_barcodes (organization_id, product_id, value, "primary", created_at, updated_at)
          SELECT organization_id, id, TRIM(barcode), true, NOW(), NOW() FROM products
          WHERE barcode IS NOT NULL AND TRIM(barcode) <> '' AND deleted_at IS NULL
        SQL
      end
    end
  end
end
