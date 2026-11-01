# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_dossier_examples')

RSpec.describe SupplierDossierExamples, type: :model do
  let(:supplier) { create(:supplier, code: 'SUP-0002') }

  before do
    # Exercise actual attachment generation and metadata reconciliation,
    # without modifying unrelated addresses, contacts or supplier schedules.
    allow(described_class).to receive(:seed_contacts)
    allow(described_class).to receive(:seed_addresses)
    allow(described_class).to receive(:seed_schedules)
    allow(described_class).to receive(:report_supplier)
  end

  def seed_supplier_documents
    described_class.send(:seed_supplier, supplier, [], nil, featured: false)
  end

  it 'makes every seeded attachment visible on the supplier document page' do
    seed_supplier_documents

    expect(supplier.documents.attachments.count).to eq(3)
    expect(supplier.supplier_documents.visible.count).to eq(3)

    page = Suppliers::DossierDocumentsPage.new(supplier:).call
    expect(page.total_count).to eq(3)
    expect(page.documents.map { |doc| doc.attachment.blob.filename.to_s })
      .to include('demo-proveedor-sup-0002-documento-01.png')
  end

  it 'repairs missing supplier document metadata when seeds are rerun' do
    seed_supplier_documents
    attachment_ids = supplier.documents.attachments.pluck(:id)
    SupplierDocument.where(supplier_id: supplier.id).delete_all

    expect(supplier.documents.attachments.count).to eq(3)
    expect(Suppliers::DossierDocumentsPage.new(supplier:).call.total_count).to eq(0)

    seed_supplier_documents

    expect(supplier.documents.attachments.pluck(:id)).to match_array(attachment_ids)
    expect(supplier.supplier_documents.visible.count).to eq(3)
    expect(Suppliers::DossierDocumentsPage.new(supplier:).call.total_count).to eq(3)
  end
end
