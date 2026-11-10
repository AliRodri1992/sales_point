# frozen_string_literal: true

# Shared SKU uniqueness boundary for products and their variants.
class ProductSkuClaim < ApplicationRecord
  belongs_to :organization

  validates :normalized_sku, presence: true, length: { maximum: 50 }
  validates :owner_type, inclusion: { in: %w[Product ProductVariant] }
  validates :owner_id, presence: true
end
