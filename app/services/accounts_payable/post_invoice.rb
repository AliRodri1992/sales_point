# frozen_string_literal: true

module AccountsPayable
  class PostInvoice
    def self.call(invoice:, actor:)
      validation = SatStatusVerifier.call(invoice:) if invoice.draft? && invoice.cfdi?
      invoice.with_lock do
        validate_invoice!(invoice)
        if invoice.cfdi?
          validate_cfdi_identity!(invoice)
          CfdiSignatureVerifier.call(xml: invoice.xml_document.download)
        end
        validate_amounts!(invoice)
        payable = invoice.create_account_payable!(payable_attributes(invoice))
        invoice.update!({ status: :posted, posted_at: Time.current }.merge(sat_attributes(validation)))
        audit_posting!(invoice, actor)
        payable
      end
    end

    def self.sat_attributes(validation)
      return {} unless validation

      { sat_status: validation.fetch(:status), sat_response_code: validation.fetch(:code),
        sat_verified_at: validation.fetch(:verified_at) }
    end

    def self.validate_invoice!(invoice)
      raise ArgumentError, 'Invoice already processed' unless invoice.draft?
      raise ArgumentError, 'Invoice total must be positive' unless invoice.total.positive?
      raise ArgumentError, 'CFDI XML is required' if invoice.cfdi? && !invoice.xml_document.attached?
    end

    def self.validate_cfdi_identity!(invoice)
      data = CfdiParser.call(xml: invoice.xml_document.download)
      expected = { uuid: invoice.uuid, issuer_rfc: invoice.supplier.rfc,
                   receiver_rfc: invoice.organization.tax_id, total: invoice.total }
      expected.each do |attribute, value|
        raise ArgumentError, "CFDI #{attribute} does not match invoice" unless data.fetch(attribute) == value
      end
      raise ArgumentError, 'CFDI currency differs from invoice' unless data.fetch(:currency_code) == invoice.currency.code
    end

    def self.validate_amounts!(invoice)
      return if invoice.subtotal.zero? && invoice.manual?

      expected = invoice.subtotal - invoice.discount + invoice.tax_amount
      raise ArgumentError, 'Invoice total does not match components' if (expected - invoice.total).abs > 0.02.to_d
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
