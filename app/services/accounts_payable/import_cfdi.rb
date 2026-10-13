# frozen_string_literal: true

module AccountsPayable
  class ImportCfdi
    def self.call(invoice:, xml:)
      data = CfdiParser.call(xml:)
      raise ArgumentError, 'Issuer RFC differs from supplier' unless data[:issuer_rfc] == invoice.supplier.rfc
      raise ArgumentError, 'Receiver RFC differs from organization' unless data[:receiver_rfc] == invoice.organization.tax_id

      currency = Currency.find_by(code: data.fetch(:currency_code))
      raise ArgumentError, 'Unknown CFDI currency' unless currency

      invoice.assign_attributes(data.except(:currency_code, :lines).merge(currency:, source: :cfdi))
      invoice.due_on ||= invoice.issued_on + invoice.supplier.credit_days.days
      invoice.received_on ||= Date.current
      invoice.supplier_invoice_lines.destroy_all if invoice.persisted? && invoice.draft?
      data.fetch(:lines).each { |line| invoice.supplier_invoice_lines.build(line) }
      invoice
    end
  end
end

