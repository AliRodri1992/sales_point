# frozen_string_literal: true

class SupplierInvoiceReceipt < ApplicationRecord
  belongs_to :supplier_invoice
  belongs_to :goods_receipt
  validates :goods_receipt_id, uniqueness: { scope: :supplier_invoice_id }
  validate :matching_purchase
  validate :invoice_must_be_draft
  before_destroy :invoice_must_be_draft_for_destroy

  private

  def invoice_must_be_draft
    errors.add(:base, 'Invoice is not editable') unless supplier_invoice&.draft?
  end

  def invoice_must_be_draft_for_destroy
    return if supplier_invoice&.draft?

    errors.add(:base, 'Invoice is not editable')
    throw(:abort)
  end


  def matching_purchase
    return unless supplier_invoice && goods_receipt

    valid = supplier_invoice.organization_id == goods_receipt.organization_id &&
            supplier_invoice.purchase_order_id == goods_receipt.purchase_order_id
    errors.add(:goods_receipt, :invalid) unless valid
  end
end
