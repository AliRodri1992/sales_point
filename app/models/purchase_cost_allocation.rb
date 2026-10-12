# frozen_string_literal: true

class PurchaseCostAllocation < ApplicationRecord
  belongs_to :organization
  belongs_to :goods_receipt_item

  validates :goods_receipt_item_id, uniqueness: true
  validates :goods_amount, :freight_amount, :insurance_amount, :landed_unit_cost,
            numericality: { greater_than_or_equal_to: 0 }
  validate :consistent_organization

  private

  def consistent_organization
    return unless goods_receipt_item

    errors.add(:goods_receipt_item, :invalid) unless goods_receipt_item.goods_receipt.organization_id ==
                                                     organization_id
  end
end
