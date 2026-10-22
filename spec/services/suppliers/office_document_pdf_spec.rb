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

  it 'returns nil when no local conversion binary is installed' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('placeholder'), filename: 'file.doc',
      content_type: 'application/msword', identify: false
    )
    allow(described_class).to receive(:available?).and_return(false)

    expect(described_class.new(blob).call).to be_nil
  end
end
