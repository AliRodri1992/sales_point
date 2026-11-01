# frozen_string_literal: true

module AccountsPayable
  class PreviewCfdi
    FIELDS = %i[uuid series folio issuer_rfc receiver_rfc subtotal discount tax_amount total
                exchange_rate issued_on received_on due_on].freeze

    def self.call(invoice:)
      { fields: invoice.attributes.symbolize_keys.slice(*FIELDS),
        currency: invoice.currency.code,
        concepts: invoice.supplier_invoice_lines.map do |line|
          { description: line.description, quantity: line.quantity, amount: line.amount }
        end }
    end
  end
end
