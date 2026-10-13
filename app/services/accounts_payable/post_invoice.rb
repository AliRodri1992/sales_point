# frozen_string_literal: true

module AccountsPayable
  class PostInvoice
    def self.call(invoice:, actor:)
      invoice.with_lock do
        validate_invoice!(invoice)
        payable = invoice.create_account_payable!(payable_attributes(invoice))
        invoice.update!(status: :posted, posted_at: Time.current)
        audit_posting!(invoice, actor)
        payable
      end
    end

    def self.validate_invoice!(invoice)
      raise ArgumentError, 'Invoice already processed' unless invoice.draft?
      raise ArgumentError, 'Invoice total must be positive' unless invoice.total.positive?
      raise ArgumentError, 'CFDI XML is required' if invoice.cfdi? && !invoice.xml_document.attached?
    end

    def self.payable_attributes(invoice)
      { organization: invoice.organization, supplier: invoice.supplier,
        amount: invoice.total, due_on: invoice.due_on }
    end

    def self.audit_posting!(invoice, actor)
      FinancialAuditEvent.record!(organization: invoice.organization, actor:, event: 'invoice.posted',
                                  subject: invoice, details: { amount: invoice.total.to_s })
    end
  end
end
