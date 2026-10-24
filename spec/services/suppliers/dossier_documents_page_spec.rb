# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe Suppliers::DossierDocumentsPage do
  let(:supplier) { create(:supplier) }

  def create_document(filename:, category:, status:, description:)
    supplier.documents.attach(
      io: StringIO.new('Sample supplier document'), filename:,
      content_type: 'text/plain'
    )
    supplier.supplier_documents.create!(
      attachment: supplier.documents.attachments.order(:id).last!, category:, status:, description:
    )
  end

  it 'filters by text, category and status together' do
    matching = create_document(
      filename: 'supplier-contract.txt', category: 'contract', status: 'active',
      description: 'Agreed wholesale prices'
    )
    create_document(
      filename: 'other-notes.txt', category: 'fiscal', status: 'inactive',
      description: 'Unrelated tax notes'
    )

    page = described_class.new(
      supplier:, filters: { query: 'wholesale', category: 'contract', status: 'active' }
    ).call

    expect(page.total_count).to eq(1)
    expect(page.documents.to_a).to eq([matching])
  end

  it 'ignores invalid category, status and date filters without losing records' do
    create_document(
      filename: 'supplier-details.txt', category: 'other', status: 'active',
      description: 'Reference document'
    )

    page = described_class.new(
      supplier:, filters: { category: 'invalid', status: 'unknown', days: '7' }
    ).call

    expect(page.total_count).to eq(1)
    expect(page.documents.size).to eq(1)
  end

  it 'applies an upload date filter for the last thirty days' do
    document = create_document(
      filename: 'recent.txt', category: 'technical', status: 'active',
      description: 'Recent specification'
    )
    old = create_document(
      filename: 'old.txt', category: 'technical', status: 'active',
      description: 'Old specification'
    )
    old.attachment.update!(created_at: 40.days.ago)

    page = described_class.new(supplier:, filters: { days: '30' }).call

    expect(page.documents.to_a).to eq([document])
  end

  it 'limits pages to a valid range and paginates document cards' do
    9.times do |index|
      create_document(
        filename: "catalog-#{index}.txt", category: 'catalog', status: 'active',
        description: "Catalog #{index}"
      )
    end

    page = described_class.new(supplier:, page: 50).call

    expect(page.total_count).to eq(9)
    expect(page.total_pages).to eq(2)
    expect(page.page).to eq(2)
    expect(page.documents.size).to eq(1)
  end
end
