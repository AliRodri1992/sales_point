# frozen_string_literal: true

class PromotionRedemption < ApplicationRecord
  include CommercialTenant

  belongs_to :promotion
  belongs_to :product
  validates :idempotency_key, presence: true, length: { maximum: 100 }, uniqueness: { scope: :organization_id }
  validates :customer_reference, length: { maximum: 100 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :discount, numericality: { greater_than_or_equal_to: 0 }
  validate :same_organization
  before_update { throw :abort }
  before_destroy { throw :abort }

  private

  def same_organization
    validate_commercial_parent(promotion, :promotion)
    validate_commercial_parent(product, :product)
  end
end
