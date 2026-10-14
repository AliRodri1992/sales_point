# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CFDI parser malformed fiscal XML branches' do
  let(:parser) { AccountsPayable::CfdiParser }
  let(:valid_xml) do
    <<~XML
      <cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4"
       Version="4.0" TipoDeComprobante="I" SubTotal="10" Total="10"
       Moneda="MXN" Fecha="2026-10-14T09:00:00">
        <cfdi:Emisor Rfc="XAXX010101001"/>
        <cfdi:Receptor Rfc="AAA010101AAA"/>
        <cfdi:Complemento>
          <TimbreFiscalDigital UUID="12345678-1234-1234-1234-1234567890AB"/>
        </cfdi:Complemento>
      </cfdi:Comprobante>
    XML
  end

  it 'rejects an oversized XML document before parsing' do
    expect { parser.call(xml: 'x' * (10.megabytes + 1)) }
      .to raise_error(ArgumentError, /exceeds 10 MB/)
  end

  it 'rejects DTD entity declarations' do
    expect { parser.call(xml: '<!DOCTYPE x [<!ENTITY z "danger">]>') }
      .to raise_error(ArgumentError, /DTD declarations/)
  end

  it 'rejects documents with unknown XML root' do
    expect { parser.call(xml: '<unknown/>') }.to raise_error(ArgumentError, /Not a CFDI/)
  end

  it 'rejects unsupported CFDI type' do
    expect { parser.call(xml: valid_xml.sub('TipoDeComprobante="I"', 'TipoDeComprobante="E"')) }
      .to raise_error(ArgumentError, /Incorrect CFDI type/)
  end

  it 'rejects CFDI without required issuer' do
    xml = valid_xml.sub('<cfdi:Emisor Rfc="XAXX010101001"/>', '')
    expect { parser.call(xml:) }.to raise_error(ArgumentError, /Missing CFDI issuer/)
  end

  it 'rejects invalid fiscal UUID' do
    xml = valid_xml.sub('12345678-1234-1234-1234-1234567890AB', 'invalid')
    expect { parser.call(xml:) }.to raise_error(ArgumentError, /Invalid CFDI UUID/)
  end

  it 'rejects malformed issue dates' do
    xml = valid_xml.sub('2026-10-14T09:00:00', 'not-a-date')
    expect { parser.call(xml:) }.to raise_error(ArgumentError, /CFDI rejected/)
  end

  it 'defaults absent taxes, discounts and exchange rates to zero or one' do
    data = parser.call(xml: valid_xml)
    expect(data).to include(total: 10.to_d, subtotal: 10.to_d, discount: 0.to_d,
                            tax_amount: 0.to_d, exchange_rate: 1.to_d)
    expect(data.fetch(:lines)).to be_empty
  end

  it 'rejects a CFDI with invalid namespace' do
    xml = valid_xml.sub('http://www.sat.gob.mx/cfd/4', 'https://example.com/false-cfdi')
    expect { parser.call(xml:) }.to raise_error(ArgumentError, /Not a CFDI/)
  end

  it 'rejects malformed XML with mismatched tags' do
    expect { parser.call(xml: '<cfdi:Comprobante>') }.to raise_error(ArgumentError, /CFDI rejected/)
  end
end
