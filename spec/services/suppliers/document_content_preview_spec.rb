# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_demo_document_office')

RSpec.describe Suppliers::DocumentContentPreview do
  let(:supplier) { Struct.new(:code).new('SUP-0001') }

  def blob(content, filename, content_type)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content), filename:, content_type:, identify: false
    )
  end

  it 'extracts visible text from a real DOCX without HTML execution' do
    office = blob(
      SupplierDemoDocumentOffice.docx_for(supplier), 'contract.docx',
      described_class::DOCX_TYPE
    )

    expect(described_class.new(office).call).to include('DEMO SUP-0001 - SIN VALIDEZ')
  end

  it 'extracts table values from a real XLSX' do
    office = blob(
      SupplierDemoDocumentOffice.xlsx_for(supplier), 'prices.xlsx',
      described_class::XLSX_TYPE
    )

    expect(described_class.new(office).call).to include('Proveedor', 'SUP-0001', 'Lista de precios')
  end

  it 'does not attempt to parse invalid compressed attachments' do
    invalid = blob('not a ZIP document', 'fake.docx', described_class::DOCX_TYPE)

    expect(described_class.new(invalid).call).to be_nil
  end

  it 'skips unrelated MIME types' do
    pdf = blob('%PDF-1.4', 'sample.pdf', 'application/pdf')

    expect(described_class.new(pdf).call).to be_nil
  end
end
