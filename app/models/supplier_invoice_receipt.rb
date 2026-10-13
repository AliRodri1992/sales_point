# frozen_string_literal: true

class SupplierInvoiceReceipt < ApplicationRecord
  belongs_to :supplier_invoice
  belongs_to :goods_receipt
  validates :goods_receipt_id, uniqueness: { scope: :supplier_invoice_id }
  validate :matching_purchase

  private

  def matching_purchase
    return unless supplier_invoice && goods_receipt

    valid = supplier_invoice.organization_id == goods_receipt.organization_id &&
            supplier_invoice.purchase_order_id == goods_receipt.purchase_order_id
    errors.add(:goods_receipt, :invalid) unless valid
  end
end
