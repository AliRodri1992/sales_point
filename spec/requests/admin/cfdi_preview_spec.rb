# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Assisted CFDI preview', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }
  let(:xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4"
        xmlns:tfd="http://www.sat.gob.mx/TimbreFiscalDigital" Version="4.0"
        TipoDeComprobante="I" Fecha="2026-10-14T09:00:00"
        SubTotal="100.00" Total="116.00" Moneda="#{supplier.currency.code}">
        <cfdi:Emisor Rfc="#{supplier.rfc}" />
        <cfdi:Receptor Rfc="#{organization.tax_id}" />
        <cfdi:Conceptos>
          <cfdi:Concepto Descripcion="Producto" Cantidad="2" ValorUnitario="50" Importe="100"/>
        </cfdi:Conceptos>
        <cfdi:Impuestos TotalImpuestosTrasladados="16"/>
        <cfdi:Complemento>
          <tfd:TimbreFiscalDigital UUID="12345678-1234-1234-1234-1234567890AB"/>
        </cfdi:Complemento>
      </cfdi:Comprobante>
    XML
  end

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def preview(payload: xml, supplier_id: supplier.id)
    post preview_cfdi_admin_supplier_invoices_path, params: {
      supplier_id:, xml_document: Rack::Test::UploadedFile.new(
        StringIO.new(payload), 'application/xml', original_filename: 'invoice.xml'
      )
    }
  end

  it 'previews concepts, calculated due date and amounts without persisting a document' do
    expect { preview }.not_to change(SupplierInvoice, :count)

    expect(response).to have_http_status(:ok)
    expect(response.headers['Cache-Control']).to eq('no-store')
    fields = response.parsed_body.fetch('fields')
    expect(fields).to include('total' => '116.0', 'issuer_rfc' => supplier.rfc)
    expect(response.parsed_body.fetch('currency')).to eq(supplier.currency.code)
    expect(response.parsed_body.fetch('concepts').first).to include('description' => 'Producto')
  end

  it 'rejects malicious document markup without writing invoices' do
    preview(payload: "<!DOCTYPE a [<!ENTITY b SYSTEM 'file:///etc/passwd'>]>\n#{xml}")

    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.supplier_invoices.count).to eq(0)
  end

  it 'rejects another organization supplier' do
    other = create(:supplier, organization: create(:organization))
    preview(supplier_id: other.id)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects a missing file' do
    post preview_cfdi_admin_supplier_invoices_path, params: { supplier_id: supplier.id }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'requires authentication' do
    sign_out user
    preview

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'shows upload and preview targets in the invoice form' do
    get new_admin_supplier_invoice_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="cfdi-preview"')
    expect(response.body).to include('data-cfdi-preview-target="result"')
  end
end
