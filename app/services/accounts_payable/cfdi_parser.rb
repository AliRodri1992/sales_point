# frozen_string_literal: true

module AccountsPayable
  class CfdiParser
    def self.call(xml:, expected_type: 'I')
      raise ArgumentError, 'Document exceeds 10 MB' if xml.bytesize > 10.megabytes
      raise ArgumentError, 'DTD declarations are not permitted' if xml.match?(/<!DOCTYPE|<!ENTITY/i)

      document = Nokogiri::XML(xml) { |options| options.strict.nonet }
      root = document.root
      raise ArgumentError, 'Not a CFDI 4.0 document' unless root&.name == 'Comprobante' &&
                                                            root.namespace&.href == 'http://www.sat.gob.mx/cfd/4' && root['Version'] == '4.0'
      raise ArgumentError, 'Incorrect CFDI type' unless root['TipoDeComprobante'] == expected_type

      issuer = root.at_xpath('./*[local-name()="Emisor"]')
      receiver = root.at_xpath('./*[local-name()="Receptor"]')
      stamp = root.at_xpath('.//*[local-name()="TimbreFiscalDigital"]')
      raise ArgumentError, 'Missing CFDI issuer, receiver or tax stamp' unless issuer && receiver && stamp

      uuid = stamp['UUID'].to_s.upcase
      unless uuid.match?(/\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\z/)
        raise ArgumentError, 'Invalid CFDI UUID'
      end

      lines = root.xpath('./*[local-name()="Conceptos"]/*[local-name()="Concepto"]').map do |node|
        { description: node['Descripcion'], quantity: BigDecimal(node['Cantidad'].to_s),
          unit_price: BigDecimal(node['ValorUnitario'].to_s), amount: BigDecimal(node['Importe'].to_s) }
      end
      { uuid:, issuer_rfc: issuer['Rfc'].to_s.upcase, receiver_rfc: receiver['Rfc'].to_s.upcase,
        series: root['Serie'], folio: root['Folio'], issued_on: Date.parse(root['Fecha'].to_s),
        subtotal: BigDecimal(root['SubTotal'].to_s), discount: BigDecimal(root['Descuento'].to_s.presence || '0'),
        total: BigDecimal(root['Total'].to_s), tax_amount: tax_total(root),
        currency_code: root['Moneda'], exchange_rate: BigDecimal(root['TipoCambio'].to_s.presence || '1'),
        payment_method: root['MetodoPago'], lines: }
    rescue Nokogiri::XML::SyntaxError, Date::Error, ArgumentError => e
      raise ArgumentError, "CFDI rejected: #{e.message}"
    end

    def self.tax_total(root)
      taxes = root.at_xpath('./*[local-name()="Impuestos"]')
      return 0.to_d unless taxes

      BigDecimal(taxes['TotalImpuestosTrasladados'].to_s.presence || '0') -
        BigDecimal(taxes['TotalImpuestosRetenidos'].to_s.presence || '0')
    end
  end
end
