# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsPayable::CfdiParser do
  let(:xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4"
        xmlns:tfd="http://www.sat.gob.mx/TimbreFiscalDigital" Version="4.0"
        TipoDeComprobante="I" Fecha="2026-10-13T12:00:00" SubTotal="100.00"
        Total="116.00" Moneda="MXN" MetodoPago="PPD">
        <cfdi:Emisor Rfc="XAXX010101000" />
        <cfdi:Receptor Rfc="AAA010101AAA" />
        <cfdi:Conceptos>
          <cfdi:Concepto Descripcion="Producto" Cantidad="2" ValorUnitario="50" Importe="100" />
        </cfdi:Conceptos>
        <cfdi:Complemento>
          <tfd:TimbreFiscalDigital UUID="12345678-1234-1234-1234-1234567890AB" />
        </cfdi:Complemento>
      </cfdi:Comprobante>
    XML
  end

  it 'extracts CFDI 4.0 information and invoice concepts' do
    data = described_class.call(xml:)

    expect(data).to include(uuid: '12345678-1234-1234-1234-1234567890AB',
                            issuer_rfc: 'XAXX010101000', total: 116.to_d)
    expect(data[:lines].first).to include(description: 'Producto', quantity: 2.to_d)
  end

  it 'blocks XML external entity and DTD declarations' do
    dangerous = '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>'
    expect { described_class.call(xml: dangerous + xml) }.to raise_error(ArgumentError)
  end

  it 'rejects a non-invoice CFDI' do
    expect { described_class.call(xml: xml.sub('TipoDeComprobante="I"', 'TipoDeComprobante="E"')) }
      .to raise_error(ArgumentError)
  end

  it 'computes transferred and withheld taxes from CFDI fiscal totals' do
    input = xml.sub('<cfdi:Conceptos>', <<~XML.strip)
      <cfdi:Impuestos TotalImpuestosTrasladados="16.00"
                      TotalImpuestosRetenidos="2.00"/>
      <cfdi:Conceptos>
    XML

    parsed = described_class.call(xml: input)

    expect(parsed[:tax_amount]).to eq(14.to_d)
  end

  it 'preserves discount and currency conversion from CFDI attributes' do
    input = xml.sub('SubTotal="100.00"', 'SubTotal="100.00" Descuento="5.00" TipoCambio="1.05"')

    parsed = described_class.call(xml: input)

    expect(parsed).to include(discount: 5.to_d, exchange_rate: BigDecimal('1.05'))
  end

  it 'rejects a missing CFDI issuer or receiver without parsing partial finances' do
    invalid = xml.sub('<cfdi:Receptor Rfc="AAA010101AAA" />', '')

    expect { described_class.call(xml: invalid) }
      .to raise_error(ArgumentError, /Missing CFDI issuer, receiver or tax stamp/)
  end

  it 'does not allow an unrecognized or malformed CFDI UUID' do
    malformed = xml.sub('12345678-1234-1234-1234-1234567890AB', 'INVALID')

    expect { described_class.call(xml: malformed) }
      .to raise_error(ArgumentError, /Invalid CFDI UUID/)
  end

  it 'rejects a CFDI that omits the digital tax stamp' do
    missing_stamp = xml.sub(%r{<tfd:TimbreFiscalDigital[^>]+/>}, '')

    expect { described_class.call(xml: missing_stamp) }
      .to raise_error(ArgumentError, /Missing CFDI issuer, receiver or tax stamp/)
  end

  it 'reports invalid issuance dates without persisting partial data' do
    incorrect_date = xml.sub('Fecha="2026-10-13T12:00:00"', 'Fecha="not-a-date"')

    expect { described_class.call(xml: incorrect_date) }
      .to raise_error(ArgumentError, /CFDI rejected/)
  end

  it 'accepts a credit-note CFDI only when that document type is expected' do
    credit_xml = xml.sub('TipoDeComprobante="I"', 'TipoDeComprobante="E"')

    expect(described_class.call(xml: credit_xml, expected_type: 'E')[:total]).to eq(116.to_d)
  end

  it 'defaults missing discount, exchange rate, and tax totals to safe values' do
    result = described_class.call(xml:)

    expect(result).to include(discount: 0.to_d, exchange_rate: 1.to_d, tax_amount: 0.to_d)
  end
end
