# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierDocument do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

  def attachment_for(record, filename: 'contract.pdf')
    record.documents.attach(
      io: StringIO.new('%PDF-1.4 sample'), filename:, content_type: 'application/pdf'
    )
    record.documents.attachments.order(:id).last
  end

  it 'rejects linking a supplier document to another suppliers attachment' do
    foreign = create(:supplier, organization:)
    other_attachment = attachment_for(foreign)
    document = described_class.new(
      supplier:, attachment: other_attachment, category: 'contract',
      status: 'active', revision_number: 1
    )

    expect(document).not_to be_valid
    expect(document.errors[:attachment]).to be_present
  end

  it 'rejects missing attachments without raising an ownership exception' do
    document = described_class.new(
      supplier:, category: 'contract', status: 'active', revision_number: 1
    )

    expect(document).not_to be_valid
    expect(document.errors[:attachment]).to be_present
  end

  it 'preserves an explicitly assigned document series during validation' do
    attachment = attachment_for(supplier)
    document = described_class.new(
      supplier:, attachment:, category: 'contract', status: 'active',
      series_id: 'existing-series', revision_number: 1
    )
    document.valid?

    expect(document.series_id).to eq('existing-series')
  end

  it 'generates a series identifier when creating an untracked document' do
    attachment = attachment_for(supplier, filename: 'another.pdf')
    document = described_class.new(
      supplier:, attachment:, category: 'other', status: 'active', revision_number: 1
    )
    document.valid?

    expect(document.series_id).to be_present
  end
end
