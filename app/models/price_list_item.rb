# frozen_string_literal: true

class PriceListItem < ApplicationRecord
  include CommercialTenant
  include CommercialPeriod

  PRICE_KEY = %i[organization_id price_list_id product_id product_variant_id product_presentation_id
                 minimum_quantity].freeze

  belongs_to :price_list, inverse_of: :price_list_items
  belongs_to :product, -> { with_deleted }, inverse_of: false
  belongs_to :product_variant, -> { with_deleted }, optional: true, inverse_of: false
  belongs_to :product_presentation, -> { with_deleted }, optional: true, inverse_of: false
  has_many :price_change_events, dependent: :restrict_with_error
  validates :price, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
  validates :minimum_quantity, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000_000_000 }
  before_validation :inherit_organization
  validate :same_organization
  validate :no_overlapping_price
  validate :active_price_targets
  validate :preserve_price_key, on: :update

  def retire!
    update!(deleted_at: Time.current) unless deleted_at
  end

  def same_price_key?(other)
    product_id == other.product_id && product_variant_id == other.product_variant_id &&
      product_presentation_id == other.product_presentation_id && minimum_quantity == other.minimum_quantity
  end

  def overlaps_period?(other, from: other.starts_at)
    (!ends_at || !from || ends_at > from) &&
      (!other.ends_at || !starts_at || other.ends_at > starts_at)
  end

  private

  def preserve_price_key
    PRICE_KEY.each do |key|
      errors.add(key, :invalid) if will_save_change_to_attribute?(key)
    end
  end

  def active_price_targets
    %i[product product_variant product_presentation].each do |attribute|
      key = "#{attribute}_id"
      next unless public_send(key) && (new_record? || will_save_change_to_attribute?(key))

      target = public_send(attribute)
      errors.add(attribute, :invalid) unless target&.active? && target.deleted_at.nil?
    end
  end

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
    return if deleted_at || !price_list&.persisted? || product_id.nil?

    duplicate = price_list.price_list_items.to_a.any? do |other|
      other != self && other.deleted_at.nil? && same_price_key?(other) && overlaps_period?(other)
    end
    errors.add(:base, I18n.t('admin.catalog_design.overlapping_price')) if duplicate
  end
end
