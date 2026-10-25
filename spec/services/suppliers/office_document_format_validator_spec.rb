# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_demo_document_office')

RSpec.describe Suppliers::OfficeDocumentFormatValidator do
  let(:supplier) { Struct.new(:code).new('SUP-0001') }

  def blob(content, filename, content_type)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename:, content_type:, identify: false)
  end

  it 'accepts a real DOCX package with the correct MIME type' do
    document = blob(SupplierDemoDocumentOffice.docx_for(supplier), 'contract.docx',
                    Suppliers::DocumentContentPreview::DOCX_TYPE)

    expect(described_class.new(document).valid?).to be(true)
  end

  it 'accepts a real XLSX package with the correct MIME type' do
    document = blob(SupplierDemoDocumentOffice.xlsx_for(supplier), 'prices.xlsx',
                    Suppliers::DocumentContentPreview::XLSX_TYPE)

    expect(described_class.new(document).valid?).to be(true)
  end

  it 'rejects plain text disguised as a DOCX even if conversion tools are installed' do
    document = blob('Word format placeholder', 'fake.docx', Suppliers::DocumentContentPreview::DOCX_TYPE)

    expect(described_class.new(document).valid?).to be(false)
  end

  it 'rejects a ZIP without the Office package manifest' do
    content = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry('word/document.xml')
      zip.write('<document/>')
    end.string
    document = blob(content, 'missing-manifest.docx', Suppliers::DocumentContentPreview::DOCX_TYPE)

    expect(described_class.new(document).valid?).to be(false)
  end

  it 'rejects Office content when the extension and declared type disagree' do
    document = blob(SupplierDemoDocumentOffice.docx_for(supplier), 'contract.xlsx',
                    Suppliers::DocumentContentPreview::DOCX_TYPE)

    expect(described_class.new(document).valid?).to be(false)
  end

  it 'rejects legacy Word files without an OLE container signature' do
    document = blob('ordinary text', 'legacy.doc', 'application/msword')

    expect(described_class.new(document).valid?).to be(false)
  end

  it 'recognizes the OLE signature of a legacy Office container' do
    document = blob(described_class::OLE_SIGNATURE + 'binary-data', 'legacy.doc', 'application/msword')

    expect(described_class.new(document).valid?).to be(true)
  end

  it 'rejects files over the upload limit without reading their data' do
    document = blob('small', 'large.docx', Suppliers::DocumentContentPreview::DOCX_TYPE)
    allow(document).to receive(:byte_size).and_return(10.megabytes + 1)
    expect(document).not_to receive(:download)

    expect(described_class.new(document).valid?).to be(false)
  end
end
