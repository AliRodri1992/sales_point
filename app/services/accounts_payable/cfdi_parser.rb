# frozen_string_literal: true

module AccountsPayable
  class CfdiParser
    CFDI_NS = 'http://www.sat.gob.mx/cfd/4'
    UUID_FORMAT = /\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\z/

    def self.call(xml:, expected_type: 'I')
      validate_input!(xml)
      document = Nokogiri::XML(xml) { |options| options.strict.nonet }
      root = document.root
      validate_comprobante!(root, expected_type)
      nodes = fiscal_nodes(root)
      build_data(root, nodes)
    rescue Nokogiri::XML::SyntaxError, Date::Error => e
      raise ArgumentError, "CFDI rejected: #{e.message}"
    end

    def self.validate_input!(xml)
      raise ArgumentError, 'Document exceeds 10 MB' if xml.bytesize > 10.megabytes
      raise ArgumentError, 'DTD declarations are not permitted' if xml.match?(/<!DOCTYPE|<!ENTITY/i)
    end

    def self.validate_comprobante!(root, expected_type)
      valid = root&.name == 'Comprobante' && root.namespace&.href == CFDI_NS &&
              root['Version'] == '4.0'
      raise ArgumentError, 'Not a CFDI 4.0 document' unless valid
      raise ArgumentError, 'Incorrect CFDI type' unless root['TipoDeComprobante'] == expected_type
    end

    def self.fiscal_nodes(root)
      nodes = {
        issuer: root.at_xpath('./*[local-name()="Emisor"]'),
        receiver: root.at_xpath('./*[local-name()="Receptor"]'),
        stamp: root.at_xpath('.//*[local-name()="TimbreFiscalDigital"]')
      }
      raise ArgumentError, 'Missing CFDI issuer, receiver or tax stamp' if nodes.values.any?(&:nil?)

      nodes
    end

    def self.build_data(root, nodes)
      uuid = nodes.fetch(:stamp)['UUID'].to_s.upcase
      raise ArgumentError, 'Invalid CFDI UUID' unless uuid.match?(UUID_FORMAT)

      fiscal_data(root, nodes).merge(uuid:, lines: concept_lines(root))
    end

    def self.fiscal_data(root, nodes)
      {
        issuer_rfc: nodes.fetch(:issuer)['Rfc'].to_s.upcase,
        receiver_rfc: nodes.fetch(:receiver)['Rfc'].to_s.upcase
      }.merge(invoice_totals(root), invoice_metadata(root))
    end

    def self.invoice_totals(root)
      {
        subtotal: BigDecimal(root['SubTotal'].to_s),
        discount: BigDecimal(root['Descuento'].to_s.presence || '0'),
        total: BigDecimal(root['Total'].to_s), tax_amount: tax_total(root)
      }
    end

    def self.invoice_metadata(root)
      {
        series: root['Serie'], folio: root['Folio'],
        issued_on: Date.parse(root['Fecha'].to_s),
        currency_code: root['Moneda'],
        exchange_rate: BigDecimal(root['TipoCambio'].to_s.presence || '1'),
        payment_method: root['MetodoPago']
      }
    end

    def self.concept_lines(root)
      root.xpath('./*[local-name()="Conceptos"]/*[local-name()="Concepto"]').map do |node|
        {
          description: node['Descripcion'], quantity: BigDecimal(node['Cantidad'].to_s),
          unit_price: BigDecimal(node['ValorUnitario'].to_s), amount: BigDecimal(node['Importe'].to_s)
        }
      end
    end

    def self.tax_total(root)
      taxes = root.at_xpath('./*[local-name()="Impuestos"]')
      return 0.to_d unless taxes

      BigDecimal(taxes['TotalImpuestosTrasladados'].to_s.presence || '0') -
        BigDecimal(taxes['TotalImpuestosRetenidos'].to_s.presence || '0')
    end
  end
end
