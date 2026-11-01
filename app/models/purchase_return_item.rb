# frozen_string_literal: true

class PurchaseReturnItem < ApplicationRecord
  has_paper_trail
  belongs_to :purchase_return
  belongs_to :goods_receipt_item

  enum :stock_disposition, { accepted: 'accepted', quarantined: 'quarantined' },
       prefix: :stock, validate: true, default: :accepted

  validates :quantity, numericality: { greater_than: 0 }
  validate :same_receipt

  private

  def same_receipt
    return unless purchase_return && goods_receipt_item

    valid = goods_receipt_item.goods_receipt_id == purchase_return.goods_receipt_id
    errors.add(:goods_receipt_item, :invalid) unless valid
  end
end
