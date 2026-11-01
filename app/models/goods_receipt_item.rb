# frozen_string_literal: true

class GoodsReceiptItem < ApplicationRecord
  belongs_to :goods_receipt
  belongs_to :purchase_order_item
  has_many :inventory_lots, dependent: :restrict_with_exception
  has_one :purchase_cost_allocation, dependent: :restrict_with_exception

  validates :delivered_quantity, :accepted_quantity, :damaged_quantity,
            numericality: { greater_than_or_equal_to: 0 }
  validate :quantities_consistent
  validate :order_item_consistent

  def rejected_quantity
    delivered_quantity - accepted_quantity
  end

  private

  def quantities_consistent
    return if delivered_quantity.nil? || accepted_quantity.nil? || damaged_quantity.nil?

    errors.add(:accepted_quantity, :invalid) if accepted_quantity + damaged_quantity > delivered_quantity
  end

  def order_item_consistent
    return unless goods_receipt && purchase_order_item

    belongs_to_order = purchase_order_item.purchase_order_id == goods_receipt.purchase_order_id
    errors.add(:purchase_order_item, :invalid) unless belongs_to_order
  end
end
