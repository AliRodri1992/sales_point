# frozen_string_literal: true

class PromotionCondition < ApplicationRecord
  include CommercialTenant

  belongs_to :promotion, inverse_of: :promotion_conditions
  belongs_to :product, -> { with_deleted }, optional: true, inverse_of: false
  belongs_to :category, -> { with_deleted }, optional: true, inverse_of: false
  enum :kind, { product: 'product', category: 'category', min_quantity: 'min_quantity',
                excluded_product: 'excluded_product', excluded_category: 'excluded_category',
                min_subtotal: 'min_subtotal', customer_segment: 'customer_segment' }, prefix: true, validate: true
  validates :product, presence: true, if: -> { kind_product? || kind_excluded_product? }
  validates :category, presence: true, if: -> { kind_category? || kind_excluded_category? }
  validates :quantity, numericality: { greater_than: 0, less_than: 1_000_000_000_000 }, if: :kind_min_quantity?
  validates :amount, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }, if: :kind_min_subtotal?
  validates :customer_segment, presence: true, length: { maximum: 100 }, if: :kind_customer_segment?
  before_validation :inherit_organization
  validate :same_organization

  private

  def inherit_organization
    self.organization ||= promotion&.organization
  end

  def same_organization
    validate_commercial_parent(promotion, :promotion)
    validate_target(product, :product) if product_id
    validate_target(category, :category) if category_id
  end

  def validate_target(target, attribute)
    validate_commercial_parent(target, attribute)
    return unless target
    return unless new_record? || will_save_change_to_kind? || will_save_change_to_attribute?("#{attribute}_id")
    return if target.active? && target.deleted_at.nil?

    errors.add(attribute, :invalid)
  end
end
