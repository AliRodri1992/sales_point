# frozen_string_literal: true

module AccountsPayable
  # Fail closed when a credit CFDI is not authentic or does not belong to this tenant.
  class ValidateCreditCfdi
    def self.call(credit_note:)
      xml = credit_note.xml_document.download
      data = CfdiParser.call(xml:, expected_type: 'E')
      expected = {
        uuid: credit_note.uuid, issuer_rfc: credit_note.supplier.rfc,
        receiver_rfc: credit_note.organization.tax_id, total: credit_note.total,
        currency_code: credit_note.currency.code
      }
      expected.each do |attribute, value|
        raise ArgumentError, "Credit CFDI #{attribute} mismatch" unless data.fetch(attribute) == value
      end
      CfdiSignatureVerifier.call(xml:)
    end
  end
end
