# frozen_string_literal: true

module AccountsPayable
  class MatchReceipts
    def self.call(invoice:, receipt_ids:, actor:)
      invoice.with_lock do
        raise ArgumentError, 'Only draft invoices can change receipts' unless invoice.draft?
        raise ArgumentError, 'Purchase order is required' unless invoice.purchase_order_id

        receipts = invoice.organization.goods_receipts.where(id: receipt_ids).order(:id).to_a
        raise ArgumentError, 'Receipt not found' unless receipts.size == receipt_ids.uniq.size
        unless receipts.all? { |receipt| receipt.purchase_order_id == invoice.purchase_order_id }
          raise ArgumentError, 'Receipts must belong to the same purchase order'
        end

        invoice.supplier_invoice_receipts.destroy_all
        receipts.each { |receipt| invoice.supplier_invoice_receipts.create!(goods_receipt: receipt) }
        FinancialAuditEvent.record!(organization: invoice.organization, actor:,
                                    event: 'invoice.receipts_matched', subject: invoice,
                                    details: { receipt_ids: receipts.map(&:id) })
      end
      invoice
    end
  end
end
