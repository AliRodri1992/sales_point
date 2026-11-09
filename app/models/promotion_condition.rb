# frozen_string_literal: true

class PromotionCondition < ApplicationRecord
  include CommercialTenant

  belongs_to :promotion, inverse_of: :promotion_conditions
  belongs_to :product, optional: true
  belongs_to :category, optional: true
  enum :kind, { product: 'product', category: 'category', min_quantity: 'min_quantity',
                min_subtotal: 'min_subtotal', customer_segment: 'customer_segment' }, prefix: true, validate: true
  validates :product, presence: true, if: :kind_product?
  validates :category, presence: true, if: :kind_category?
  validates :quantity, numericality: { greater_than: 0 }, if: :kind_min_quantity?
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, if: :kind_min_subtotal?
  validates :customer_segment, presence: true, length: { maximum: 100 }, if: :kind_customer_segment?
  before_validation :inherit_organization
  validate :same_organization

  private

  def inherit_organization
    self.organization ||= promotion&.organization
  end

  def same_organization
    validate_commercial_parent(promotion, :promotion)
    validate_commercial_parent(product, :product) if product
    if category && category.organization_id.present? && category.organization_id != organization_id
      errors.add(:category, :invalid)
    end
  end
end
