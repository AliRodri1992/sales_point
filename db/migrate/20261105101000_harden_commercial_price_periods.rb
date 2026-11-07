# frozen_string_literal: true

class HardenCommercialPricePeriods < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'btree_gist' unless extension_enabled?('btree_gist')
    add_index :price_list_items, [:organization_id, :product_id, :id], unique: true, name: 'idx_list_item_tenant_product'
    add_foreign_key :price_change_events, :price_list_items,
                    column: [:organization_id, :product_id, :price_list_item_id],
                    primary_key: [:organization_id, :product_id, :id]
    add_exclusion_constraint :price_list_items,
                             "price_list_id WITH =, product_id WITH =, COALESCE(product_variant_id, 0) WITH =, COALESCE(product_presentation_id, 0) WITH =, tsrange(starts_at, ends_at, '[)') WITH &&",
                             using: :gist, where: 'deleted_at IS NULL',
                             deferrable: :deferred, name: 'commercial_price_periods'
  end
end
