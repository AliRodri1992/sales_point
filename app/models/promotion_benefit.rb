# frozen_string_literal: true

class PromotionBenefit < ApplicationRecord
  include CommercialTenant

  belongs_to :promotion, inverse_of: :promotion_benefits
  enum :kind, { percentage: 'percentage', fixed_amount: 'fixed_amount' }, validate: true
  validates :value, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?
  before_validation :inherit_organization
  validate :same_organization

  def discount_for(subtotal)
    amount = percentage? ? subtotal * value / 100 : value
    [amount.round(2), subtotal].min
  end

  private

  def inherit_organization
    self.organization ||= promotion&.organization
  end

  def same_organization
    validate_commercial_parent(promotion, :promotion)
  end
end
