# frozen_string_literal: true

class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :product
  belongs_to :supplier_product, optional: true
  has_many :goods_receipt_items, dependent: :restrict_with_exception

  validates :quantity, :units_per_package, numericality: { greater_than: 0 }
  validates :unit_price, :nonrecoverable_tax, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percent, numericality: { in: 0..100 }
  validate :supplier_product_consistent

  def line_total
    (quantity / units_per_package) * unit_price * (1 - (discount_percent / 100)) + nonrecoverable_tax
  end

  def received_quantity
    goods_receipt_items.sum(:accepted_quantity)
  end

  private

  def supplier_product_consistent
    return unless supplier_product && purchase_order

    valid = supplier_product.supplier_id == purchase_order.supplier_id &&
            supplier_product.product_id == product_id &&
            supplier_product.organization_id == purchase_order.organization_id
    errors.add(:supplier_product, :invalid) unless valid
  end
end
