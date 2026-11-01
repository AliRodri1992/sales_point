# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsPayable::ImportCfdi do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:invoice) do
    SupplierInvoice.new(organization:, supplier:, currency: supplier.currency, created_by: user)
  end

  let(:xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4"
        xmlns:tfd="http://www.sat.gob.mx/TimbreFiscalDigital" Version="4.0"
        TipoDeComprobante="I" Fecha="2026-10-13T12:00:00"
        SubTotal="200.00" Total="232.00" Moneda="#{supplier.currency.code}" MetodoPago="PPD">
        <cfdi:Emisor Rfc="#{supplier.rfc}"/>
        <cfdi:Receptor Rfc="#{organization.tax_id}"/>
        <cfdi:Conceptos>
          <cfdi:Concepto Descripcion="Artículo" Cantidad="2"
            ValorUnitario="100.00" Importe="200.00"/>
        </cfdi:Conceptos>
        <cfdi:Impuestos TotalImpuestosTrasladados="32.00"/>
        <cfdi:Complemento>
          <tfd:TimbreFiscalDigital UUID="12345678-1234-1234-1234-1234567890AB"/>
        </cfdi:Complemento>
      </cfdi:Comprobante>
    XML
  end

  it 'extracts fiscal information, lines and vendor payment terms' do
    result = described_class.call(invoice:, xml:)

    expect(result).to equal(invoice)
    expect(result).to be_cfdi
    expect(result).to have_attributes(
      total: 232.to_d, subtotal: 200.to_d, tax_amount: 32.to_d,
      issuer_rfc: supplier.rfc, receiver_rfc: organization.tax_id
    )
    expect(result.supplier_invoice_lines.first).to have_attributes(
      description: 'Artículo', quantity: 2.to_d, amount: 200.to_d
    )
    expect(result.due_on).to eq(result.issued_on + supplier.credit_days.days)
    expect(result.save).to be(true)
    expect(result.reload.supplier_invoice_lines.count).to eq(1)
  end

  it 'rejects an issuer RFC from a different supplier' do
    modified = xml.sub(supplier.rfc, 'XAXX010101000')

    expect { described_class.call(invoice:, xml: modified) }
      .to raise_error(ArgumentError, 'Issuer RFC differs from supplier')
    expect(invoice.supplier_invoice_lines).to be_empty
  end

  it 'rejects a receiver RFC from a different organization' do
    modified = xml.sub(organization.tax_id, 'AAA010101AAA')

    expect { described_class.call(invoice:, xml: modified) }
      .to raise_error(ArgumentError, 'Receiver RFC differs from organization')
  end

  it 'rejects unrecognized currencies instead of silently converting amounts' do
    modified = xml.sub(%(Moneda="#{supplier.currency.code}"), 'Moneda="ZZZ"')

    expect { described_class.call(invoice:, xml: modified) }
      .to raise_error(ArgumentError, 'Unknown CFDI currency')
  end
end
