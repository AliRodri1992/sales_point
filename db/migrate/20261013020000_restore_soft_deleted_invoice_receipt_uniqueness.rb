# frozen_string_literal: true

class RestoreSoftDeletedInvoiceReceiptUniqueness < ActiveRecord::Migration[8.1]
  def change
    remove_index :supplier_invoice_receipts, name: 'idx_supplier_invoice_receipt_unique'
    add_index :supplier_invoice_receipts, %i[supplier_invoice_id goods_receipt_id],
              unique: true, where: 'deleted_at IS NULL',
              name: 'idx_supplier_invoice_receipt_unique'
  end
end
