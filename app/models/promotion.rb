# frozen_string_literal: true

class Promotion < ApplicationRecord
  include CommercialTenant
  include CommercialPeriod
  include CommercialCurrency

  has_many :promotion_conditions, inverse_of: :promotion, dependent: :restrict_with_error
  has_many :promotion_benefits, inverse_of: :promotion, dependent: :restrict_with_error
  has_many :promotion_redemptions, dependent: :restrict_with_error
  accepts_nested_attributes_for :promotion_conditions, allow_destroy: true, reject_if: :all_blank, limit: 20
  accepts_nested_attributes_for :promotion_benefits, allow_destroy: true, reject_if: :all_blank, limit: 10
  normalizes :code, with: ->(value) { value.strip.upcase }
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 }, uniqueness: { scope: :organization_id }
  validates :usage_limit, :customer_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  enum :status, { draft: 'draft', active: 'active', archived: 'archived' }, validate: true, default: :draft
  validate :active_promotion_has_benefits

  private

  def active_promotion_has_benefits
    errors.add(:promotion_benefits, :blank) if active? && promotion_benefits.reject(&:marked_for_destruction?).empty?
  end
end
