# frozen_string_literal: true

module AccountsPayable
  class CancelInvoice
    def self.call(invoice:, actor:)
      invoice.with_lock do
        raise ArgumentError, 'Invoice already cancelled' if invoice.cancelled?
        raise ArgumentError, 'Cannot cancel an invoice with financial movements' if financial_movements?(invoice)

        invoice.update!(status: :cancelled, cancelled_at: Time.current)
        FinancialAuditEvent.record!(organization: invoice.organization, actor:,
                                    event: 'invoice.cancelled', subject: invoice)
      end
      invoice
    end

    def self.financial_movements?(invoice)
      payable = invoice.account_payable
      return false unless payable

      payable.supplier_payment_allocations.exists? || payable.supplier_credit_allocations.exists?
    end
  end
end
