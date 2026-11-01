# frozen_string_literal: true

module AccountsPayable
  class MatchReceipts
    def self.call(invoice:, receipt_ids:, actor:)
      new(invoice:, receipt_ids:, actor:).call
    end

    def initialize(invoice:, receipt_ids:, actor:)
      @invoice = invoice
      @receipt_ids = receipt_ids.map(&:to_i).uniq
      @actor = actor
    end

    def call
      @invoice.with_lock do
        validate_draft!
        receipts = valid_receipts
        @invoice.supplier_invoice_receipts.destroy_all
        receipts.each { |receipt| @invoice.supplier_invoice_receipts.create!(goods_receipt: receipt) }
        audit_matching!(receipts)
      end
      @invoice
    end

    private

    def validate_draft!
      raise ArgumentError, 'Only draft invoices can change receipts' unless @invoice.draft?
      raise ArgumentError, 'Purchase order is required' unless @invoice.purchase_order_id
    end

    def valid_receipts
      receipts = @invoice.organization.goods_receipts.where(id: @receipt_ids).order(:id).to_a
      raise ArgumentError, 'Receipt not found' unless receipts.size == @receipt_ids.size
      raise ArgumentError, 'Receipts must belong to the same purchase order' unless matching_receipts?(receipts)
      raise ArgumentError, 'Receipt already linked to another active invoice' if duplicated_receipts?

      receipts
    end

    def matching_receipts?(receipts)
      receipts.all? { |receipt| receipt.purchase_order_id == @invoice.purchase_order_id && receipt.posted? }
    end

    def duplicated_receipts?
      conditions = { organization_id: @invoice.organization_id, status: %w[draft posted] }
      SupplierInvoiceReceipt.joins(:supplier_invoice).where(goods_receipt_id: @receipt_ids)
                            .where.not(supplier_invoice_id: @invoice.id)
                            .exists?(supplier_invoices: conditions)
    end

    def audit_matching!(receipts)
      FinancialAuditEvent.record!(organization: @invoice.organization, actor: @actor,
                                  event: 'invoice.receipts_matched', subject: @invoice,
                                  details: { receipt_ids: receipts.map(&:id) })
    end
  end
end
