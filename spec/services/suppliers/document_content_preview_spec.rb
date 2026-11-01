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

  it 'extracts text from an intact Office ZIP after format validation' do
    document = blob(SupplierDemoDocumentOffice.docx_for(supplier), 'intact.docx',
                    described_class::DOCX_TYPE)

    expect(described_class.new(document).call).to include('DEMO SUP-0001')
  end

  it 'does not attempt to parse invalid compressed attachments' do
    invalid = blob('not a ZIP document', 'fake.docx', described_class::DOCX_TYPE)

    expect(described_class.new(invalid).call).to be_nil
  end

  it 'refuses an unrelated ZIP disguised as an Office attachment' do
    archive = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry('notes.txt')
      zip.write('not a spreadsheet')
    end.string
    fake = blob(archive, 'spoofed.xlsx', described_class::XLSX_TYPE)

    expect(described_class.new(fake).call).to be_nil
  end

  it 'returns a blank text result for a valid DOCX without visible paragraphs' do
    content = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry('[Content_Types].xml')
      zip.write(SupplierDemoDocumentOffice.docx_content_types)
      zip.put_next_entry('word/document.xml')
      zip.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body/></w:document>')
    end.string
    document = blob(content, 'blank.docx', described_class::DOCX_TYPE)

    expect(described_class.new(document).call).to eq('')
  end

  it 'skips unrelated MIME types' do
    pdf = blob('%PDF-1.4', 'sample.pdf', 'application/pdf')

    expect(described_class.new(pdf).call).to be_nil
  end
end
