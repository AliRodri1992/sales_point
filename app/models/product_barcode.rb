# frozen_string_literal: true

class ProductBarcode < ApplicationRecord
  include CommercialTenant

  belongs_to :product, inverse_of: :product_barcodes
  belongs_to :product_variant, optional: true
  belongs_to :product_presentation, optional: true
  normalizes :value, with: ->(value) { value.strip }
  validates :value, presence: true, length: { maximum: 100 },
                    uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :symbology, inclusion: { in: %w[code128 ean13 ean8 upca qr] }
  before_validation :inherit_organization
  validate :same_product
  validate :usable_barcode
  validate :primary_matches_product

  private

  def primary_matches_product
    return unless primary? && value != product&.barcode

    errors.add(:value, :invalid)
  end

  def usable_barcode
    return if value.blank? || Products::BarcodeFormat.valid?(value, symbology)

    errors.add(:value, :invalid)
  end

  def inherit_organization
    self.organization ||= product&.organization
  end

  def same_product
    validate_commercial_parent(product, :product)
    validate_product_option(product_variant, :product_variant)
    validate_product_option(product_presentation, :product_presentation)
  end
end
