# frozen_string_literal: true

class PurchaseQuotationItem < ApplicationRecord
  belongs_to :purchase_quotation
  belongs_to :product
  belongs_to :supplier_product, optional: true

  validates :quantity, :units_per_package, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percent, numericality: { in: 0..100 }
  validates :lead_time_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :consistent_links

  def quoted_amount
    (quantity / units_per_package) * unit_price * (1 - (discount_percent / 100))
  end

  private

  def consistent_links
    return unless purchase_quotation

    organization = purchase_quotation.organization_id
    errors.add(:product, :invalid) if product && product.organization_id != organization
    validate_supplier_product(organization) if supplier_product
  end

  def validate_supplier_product(organization)
    valid = supplier_product.organization_id == organization &&
            supplier_product.supplier_id == purchase_quotation.supplier_id &&
            supplier_product.product_id == product_id
    errors.add(:supplier_product, :invalid) unless valid
  end
end
