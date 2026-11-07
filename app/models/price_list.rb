# frozen_string_literal: true

class PriceList < ApplicationRecord
  include CommercialTenant
  include CommercialPeriod
  include CommercialCurrency

  has_many :price_list_items, inverse_of: :price_list, dependent: :restrict_with_error
  accepts_nested_attributes_for :price_list_items, reject_if: :all_blank, limit: 50
  normalizes :code, with: ->(value) { value.strip.upcase }
  normalizes :customer_segment, with: ->(value) { value.strip.presence }
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 }, uniqueness: { scope: :organization_id }
  validates :customer_segment, length: { maximum: 100 }
  validate :nonoverlapping_submitted_prices
  enum :status, { draft: 'draft', active: 'active', archived: 'archived' }, validate: true, default: :draft

  private

  def nonoverlapping_submitted_prices
    overlap = price_list_items.to_a.combination(2).any? do |left, right|
      left.same_price_key?(right) && left.overlaps_period?(right)
    end
    errors.add(:base, I18n.t('admin.catalog_design.overlapping_price')) if overlap
  end
end
