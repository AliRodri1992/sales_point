# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::DocumentPresenter do
  let(:supplier) { create(:supplier) }

  def attachment_for(filename, content_type: 'application/pdf')
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('test document'), filename:, content_type:, identify: false
    )
    supplier.documents.attach(blob)
    ActiveStorage::Attachment.where(record: supplier, name: 'documents').order(:id).last
  end

  it 'infers all supported filing categories from the filename' do
    cases = {
      'contrato_de_servicios.pdf' => 'contract',
      'RFC SAT.pdf' => 'fiscal',
      'catalogo.xlsx' => 'catalog',
      'ficha-tecnica.docx' => 'technical',
      'identificacion.jpeg' => 'legal',
      'miscellaneous.pdf' => 'other'
    }
    cases.each do |filename, expected|
      expect(described_class.new(attachment_for(filename)).category).to eq(expected)
    end
  end

  it 'chooses the corresponding icon for each file extension' do
    cases = {
      'invoice.pdf' => 'pdf', 'statement.docx' => 'word', 'prices.xls' => 'excel',
      'photo.png' => 'image', 'notes.xml' => 'text', 'archive.other' => 'file'
    }
    cases.each do |filename, expected|
      expect(described_class.new(attachment_for(filename)).icon).to eq(expected)
    end
  end

  it 'reads legacy attachment metadata and defaults an invalid status safely' do
    attachment = attachment_for('contract.pdf')
    custom = {
      'supplier_category' => 'fiscal',
      'supplier_description' => 'Tax documentation',
      'supplier_status' => 'inactive'
    }
    attachment.blob.update!(metadata: attachment.blob.metadata.merge('custom' => custom))
    presenter = described_class.new(attachment)
    expect(presenter.category).to eq('fiscal')
    expect(presenter.description).to eq('Tax documentation')
    expect(presenter.status).to eq('inactive')

    invalid = { 'supplier_category' => 'not_a_category', 'supplier_status' => 'bad_value' }
    attachment.blob.update!(metadata: attachment.blob.metadata.merge('custom' => invalid))
    fallback = described_class.new(attachment.reload)
    expect(fallback.category).to eq('contract')
    expect(fallback.status).to eq('active')
  end

  it 'uses document-specific metadata over metadata stored on the blob' do
    attachment = attachment_for('contract.pdf')
    SupplierDocument.import_existing!(supplier)
    record = supplier.supplier_documents.find_by!(attachment_id: attachment.id)
    record.update!(category: 'legal', status: 'inactive', description: 'Reviewed contract')
    presenter = described_class.new(record)

    expect(presenter.category).to eq('legal')
    expect(presenter.status).to eq('inactive')
    expect(presenter.description).to eq('Reviewed contract')
    expect(presenter.attachment).to eq(attachment)
  end

  it 'distinguishes PDFs, images, text and unsupported files' do
    cases = {
      ['document.pdf', 'application/pdf'] => 'pdf',
      ['photo.jpeg', 'image/jpeg'] => 'image',
      ['notes.txt', 'text/plain'] => 'text',
      ['binary.bin', 'application/octet-stream'] => 'text'
    }
    cases.each do |(filename, content_type), expected|
      presenter = described_class.new(attachment_for(filename, content_type:))
      expect(presenter.preview_kind).to eq(expected)
      expect(presenter.previewable?).to eq(expected != 'none')
    end
  end

  it 'uses Office PDF previews when conversion is available' do
    allow(Suppliers::OfficeDocumentPdf).to receive(:available?).and_return(true)
    doc = described_class.new(attachment_for('report.doc', content_type: 'application/msword'))
    expect(doc.preview_kind).to eq('pdf')
  end

  it 'falls back to safe text for modern Office files without a converter' do
    allow(Suppliers::OfficeDocumentPdf).to receive(:available?).and_return(false)
    docx = described_class.new(
      attachment_for('report.docx', content_type: Suppliers::DocumentContentPreview::DOCX_TYPE)
    )
    legacy = described_class.new(attachment_for('report.doc', content_type: 'application/msword'))

    expect(docx.preview_kind).to eq('text')
    expect(legacy.preview_kind).to eq('none')
  end

  it 'uses all safe text MIME types and rejects unsupported text formats' do
    %w[text/csv application/csv text/xml application/xml].each do |mime|
      document = described_class.new(attachment_for('report.dat', content_type: mime))
      expect(document.preview_kind).to eq('text')
    end
    document = described_class.new(attachment_for('data.dat', content_type: 'application/x-executable'))
    allow(document.attachment.blob).to receive(:content_type).and_return('application/x-executable')
    expect(document.preview_kind).to eq('none')
  end

  it 'recognizes jpeg pictures and legacy spreadsheet file icons' do
    picture = described_class.new(attachment_for('image.jpg', content_type: 'image/jpeg'))
    spreadsheet = described_class.new(attachment_for('ledger.csv', content_type: 'text/csv'))

    expect(picture.preview_kind).to eq('image')
    expect(picture.icon).to eq('image')
    expect(spreadsheet.icon).to eq('excel')
  end
end
