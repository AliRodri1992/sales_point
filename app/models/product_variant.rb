# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  include CommercialTenant
  include ProductSkuReservation

  attr_accessor :client_key

  belongs_to :product, inverse_of: :product_variants
  has_many :product_barcodes, dependent: :restrict_with_error
  has_many :price_list_items, dependent: :restrict_with_error
  store_accessor :options, :size, :color, :model
  normalizes :sku, with: ->(value) { value.strip.presence }
  validates :name, presence: true, length: { maximum: 100 }
  validates :sku, length: { maximum: 50 },
                  uniqueness: { scope: :organization_id, allow_nil: true, case_sensitive: false }
  enum :status, { active: 'active', inactive: 'inactive' }, validate: true, default: :active
  validate :same_organization
  validate :sku_available_among_products, if: -> { sku.present? }
  validate :valid_options
  before_validation :inherit_organization

  private

  def sku_available_among_products
    parent_uses_sku = product&.sku.present? && product.sku.casecmp?(sku)
    existing = Product.where(organization_id:).exists?(['lower(sku) = lower(?)', sku])
    errors.add(:sku, :taken) if parent_uses_sku || existing
  end

  def inherit_organization
    self.organization ||= product&.organization
  end

  def same_organization
    validate_commercial_parent(product, :product)
  end

  def valid_options
    valid = options.is_a?(Hash) && options.size <= 10 && options.all? do |key, value|
      key.is_a?(String) && key.length <= 50 && value.is_a?(String) && value.length <= 100
    end
    errors.add(:options, :invalid) unless valid
  end
end
