# frozen_string_literal: true

module AccountsPayable
  class PostInvoice
    def self.call(invoice:, actor:)
      invoice.with_lock do
        raise ArgumentError, 'Invoice already processed' unless invoice.draft?
        raise ArgumentError, 'Invoice total must be positive' unless invoice.total.positive?
        raise ArgumentError, 'CFDI XML is required' if invoice.cfdi? && !invoice.xml_document.attached?

        payable = invoice.create_account_payable!(
          organization: invoice.organization, supplier: invoice.supplier,
          amount: invoice.total, due_on: invoice.due_on
        )
        invoice.update!(status: :posted, posted_at: Time.current)
        FinancialAuditEvent.record!(organization: invoice.organization, actor:, event: 'invoice.posted',
                                    subject: invoice, details: { amount: invoice.total.to_s })
        payable
      end
    end
  end
end

