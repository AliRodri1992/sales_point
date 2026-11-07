# frozen_string_literal: true

class PriceListItem < ApplicationRecord
  include CommercialTenant
  include CommercialPeriod

  belongs_to :price_list, inverse_of: :price_list_items
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :product_presentation, optional: true
  has_many :price_change_events, dependent: :restrict_with_error
  validates :price, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
  before_validation :inherit_organization
  validate :same_organization
  validate :no_overlapping_price

  def same_price_key?(other)
    product_id == other.product_id && product_variant_id == other.product_variant_id &&
      product_presentation_id == other.product_presentation_id
  end

  def overlaps_period?(other)
    (!ends_at || !other.starts_at || ends_at > other.starts_at) &&
      (!other.ends_at || !starts_at || other.ends_at > starts_at)
  end

  private

  def inherit_organization
    self.organization ||= price_list&.organization
  end

  def same_organization
    validate_commercial_parent(price_list, :price_list)
    validate_commercial_parent(product, :product)
    validate_product_option(product_variant, :product_variant)
    validate_product_option(product_presentation, :product_presentation)
  end

  def no_overlapping_price
    return unless price_list&.persisted? && product_id

    duplicate = price_list.price_list_items.to_a.any? do |other|
      other != self && same_price_key?(other) && overlaps_period?(other)
    end
    errors.add(:base, I18n.t('admin.catalog_design.overlapping_price')) if duplicate
  end
end
