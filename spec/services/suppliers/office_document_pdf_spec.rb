# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_demo_document_office')

RSpec.describe Suppliers::OfficeDocumentPdf do
  it 'rejects unsupported document types before attempting conversion' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('%PDF-1.4'), filename: 'sample.pdf',
      content_type: 'application/pdf', identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)

    expect(described_class.new(blob).call).to be_nil
  end

  it 'converts a supported document into a PDF in a private directory' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(SupplierDemoDocumentOffice.docx_for(Struct.new(:code).new('SUP-0001'))), filename: 'report.docx',
      content_type: described_class::CONTENT_TYPES.first, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    allow(SupplierOfficeConverterProcess).to receive(:call) do |directory:, input:|
      expect(File.basename(input)).to eq('document.docx')
      File.binwrite(File.join(directory, 'document.pdf'), '%PDF-1.4 mock conversion')
      true
    end

    expect(described_class.new(blob).call).to start_with('%PDF-1.4')
  end

  it 'rejects conversion output without a valid PDF signature' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(SupplierDemoDocumentOffice.docx_for(Struct.new(:code).new('SUP-0001'))), filename: 'report.docx',
      content_type: described_class::CONTENT_TYPES.first, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    allow(SupplierOfficeConverterProcess).to receive(:call) do |directory:, **|
      File.binwrite(File.join(directory, 'document.pdf'), 'This is not a PDF')
      true
    end

    expect(described_class.new(blob).call).to be_nil
  end

  it 'does not use incomplete output when the conversion subprocess fails' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(SupplierDemoDocumentOffice.docx_for(Struct.new(:code).new('SUP-0001'))), filename: 'report.docx',
      content_type: described_class::CONTENT_TYPES.first, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    allow(SupplierOfficeConverterProcess).to receive(:call).and_return(false)

    expect(described_class.new(blob).call).to be_nil
  end

  it 'rejects an extension inconsistent with an allowed Office media type' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('invalid Office extension'), filename: 'report.bin',
      content_type: described_class::CONTENT_TYPES.first, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)

    expect(described_class.new(blob).call).to be_nil
  end

  it 'rejects documents exceeding the ten-megabyte input limit' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('placeholder'), filename: 'report.doc',
      content_type: 'application/msword', identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    allow(blob).to receive(:byte_size).and_return(10.megabytes + 1)

    expect(described_class.new(blob).call).to be_nil
  end

  it 'allows conversion of a structurally valid XLSX package' do
    document = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(SupplierDemoDocumentOffice.xlsx_for(Struct.new(:code).new('SUP-0001'))),
      filename: 'prices.xlsx', content_type: described_class::CONTENT_TYPES.second, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    allow(SupplierOfficeConverterProcess).to receive(:call) do |directory:, **|
      File.binwrite(File.join(directory, 'document.pdf'), '%PDF-1.4 spreadsheet conversion')
      true
    end

    expect(described_class.new(document).call).to start_with('%PDF-1.4')
  end

  it 'does not pass an incomplete ZIP archive to LibreOffice' do
    zipped = Zip::OutputStream.write_buffer do |archive|
      archive.put_next_entry('[Content_Types].xml')
      archive.write(SupplierDemoDocumentOffice.docx_content_types)
    end.string
    document = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(zipped), filename: 'incomplete.docx',
      content_type: described_class::CONTENT_TYPES.first, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    expect(SupplierOfficeConverterProcess).not_to receive(:call)

    expect(described_class.new(document).call).to be_nil
  end

  it 'avoids invoking LibreOffice for a truncated ZIP signature' do
    document = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("PK\x03\x04".b), filename: 'truncated.docx',
      content_type: described_class::CONTENT_TYPES.first, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    expect(SupplierOfficeConverterProcess).not_to receive(:call)

    expect(described_class.new(document).call).to be_nil
  end

  it 'does not convert plain text masquerading as a DOCX' do
    document = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('Word format placeholder'), filename: 'fake.docx',
      content_type: described_class::CONTENT_TYPES.first, identify: false
    )
    allow(described_class).to receive(:available?).and_return(true)
    expect(SupplierOfficeConverterProcess).not_to receive(:call)

    expect(described_class.new(document).call).to be_nil
  end

  it 'returns nil when no local conversion binary is installed' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('placeholder'), filename: 'file.doc',
      content_type: 'application/msword', identify: false
    )
    allow(described_class).to receive(:available?).and_return(false)

    expect(described_class.new(blob).call).to be_nil
  end
end
