# frozen_string_literal: true

require 'rails_helper'

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
      io: StringIO.new('test office bytes'), filename: 'report.docx',
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
      io: StringIO.new('test office bytes'), filename: 'report.docx',
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
      io: StringIO.new('test office bytes'), filename: 'report.docx',
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

  it 'returns nil when no local conversion binary is installed' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('placeholder'), filename: 'file.doc',
      content_type: 'application/msword', identify: false
    )
    allow(described_class).to receive(:available?).and_return(false)

    expect(described_class.new(blob).call).to be_nil
  end
end
