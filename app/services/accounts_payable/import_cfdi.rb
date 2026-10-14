# frozen_string_literal: true

module AccountsPayable
  class ImportCfdi
    def self.call(invoice:, xml:)
      new(invoice:, xml:).call
    end

    def initialize(invoice:, xml:)
      @invoice = invoice
      @data = CfdiParser.call(xml:)
    end

    def call
      validate_supplier!
      currency = Currency.find_by(code: @data.fetch(:currency_code))
      raise ArgumentError, 'Unknown CFDI currency' unless currency

      assign_header!(currency)
      replace_lines!
      @invoice
    end

    private

    def validate_supplier!
      raise ArgumentError, 'Issuer RFC differs from supplier' unless @data[:issuer_rfc] == @invoice.supplier.rfc
      return if @data[:receiver_rfc] == @invoice.organization.tax_id

      raise ArgumentError, 'Receiver RFC differs from organization'
    end

    def assign_header!(currency)
      @invoice.assign_attributes(@data.except(:currency_code, :lines).merge(currency:, source: :cfdi))
      @invoice.due_on ||= @invoice.issued_on + @invoice.supplier.credit_days.days
      @invoice.received_on ||= Date.current
    end

    def replace_lines!
      @invoice.supplier_invoice_lines.destroy_all if @invoice.persisted? && @invoice.draft?
      @data.fetch(:lines).each { |line| @invoice.supplier_invoice_lines.build(line) }
    end
  end
end
