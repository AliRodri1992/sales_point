# frozen_string_literal: true

class PriceList < ApplicationRecord
  include CommercialTenant
  include CommercialPeriod
  include CommercialCurrency
  include CommercialLifecycle

  CODE_PREFIX = 'LP'

  has_many :price_list_items, inverse_of: :price_list, dependent: :restrict_with_error
  accepts_nested_attributes_for :price_list_items, reject_if: :all_blank, limit: 50
  normalizes :customer_segment, with: ->(value) { value.strip.presence }
  validates :name, presence: true, length: { maximum: 100 }
  validates :customer_segment, length: { maximum: 100 }
  validate :nonoverlapping_submitted_prices

  def available_row?(item, at:)
    valid_from = [at, starts_at].compact.max
    item.deleted_at.nil? && !item.marked_for_destruction? && item.overlaps_period?(self, from: valid_from)
  end

  private

  def activation_content?(at)
    price_list_items.any? { |item| available_row?(item, at:) }
  end

  def nonoverlapping_submitted_prices
    return unless association(:price_list_items).target.any?(&:changed_for_autosave?)

    overlap = price_list_items.reject(&:deleted_at).combination(2).any? do |left, right|
      left.same_price_key?(right) && left.overlaps_period?(right)
    end
    errors.add(:base, I18n.t('admin.catalog_design.overlapping_price')) if overlap
  end
end
