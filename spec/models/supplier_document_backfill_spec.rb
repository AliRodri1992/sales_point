# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier document backfill', type: :model do
  let(:supplier) { create(:supplier) }

  it 'tracks new attachments and does not create duplicates during repeated backfills' do
    supplier.documents.attach(
      io: StringIO.new('%PDF-1.4 example'), filename: 'archived-invoice.pdf',
      content_type: 'application/pdf'
    )
    SupplierDocument.import_existing!(supplier)
    SupplierDocument.import_existing!(supplier)

    expect(supplier.supplier_documents.count).to eq(1)
    expect(supplier.supplier_documents.first.attachment.blob.filename.to_s).to eq('archived-invoice.pdf')
  end
end
