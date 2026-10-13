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
end
