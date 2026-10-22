# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_demo_document_office')

RSpec.describe 'Supplier document library', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  after { @tempfiles&.each(&:close!) }

  def upload(filename = 'contract.pdf', mime = 'application/pdf')
    @tempfiles ||= []
    tempfile = Tempfile.new(['supplier-document', File.extname(filename)])
    tempfile.write(mime == 'text/plain' ? 'Plain text supplier note' : '%PDF-1.4 sample supplier document')
    tempfile.rewind
    @tempfiles << tempfile
    Rack::Test::UploadedFile.new(tempfile.path, mime, original_filename: filename)
  end

  def attachment
    supplier.documents.attachments.order(:id).last
  end

  def panel
    Nokogiri::HTML(response.body).at_css('section[data-section="documents"]')
  end

  it 'preserves the original document cards, aligned filters, upload area and preview modal' do
    supplier.documents.attach(upload('supplier-contract.pdf'))
    supplier.documents.attach(
      upload('specification.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    )

    get admin_supplier_path(supplier, tab: 'documents')

    expect(response).to have_http_status(:ok)
    expect(panel['data-controller']).to eq('supplier-documents')
    expect(panel.css('[data-supplier-documents-target="card"]').size).to eq(2)
    expect(panel.at_css('[data-supplier-documents-target="list"]').name).to eq('div')
    expect(panel.at_css('[data-supplier-documents-target="list"]')['class']).to include('md:grid-cols-2')
    cards = panel.css('article[data-supplier-documents-target="card"]')
    expect(cards.size).to eq(2)
    expect(cards.pluck('class')).to all(include('min-h-36'))
    expect(cards.pluck('class')).to all(include('p-3'))
    expect(panel.at_css('[data-supplier-documents-target="list"]')['class']).to include('auto-rows-fr')
    expect(cards.map { |card| card.at_css('button span[title]') }).to all(be_present)
    expect(panel.at_css('table')).to be_nil
    expect(panel.css('article[data-supplier-documents-target="card"] img[src*="supplier-document-"]').size).to eq(2)
    expect(panel.at_css('[data-supplier-documents-target="filters"]')['class']).to include('items-end')
    expect(panel.at_css('[data-supplier-documents-target="dropzone"]')).to be_present
    expect(panel.at_css('input[type="file"][multiple]')['name']).to eq('document[files][]')
    expect(panel.css('img[src*="supplier-document-"]').size).to eq(2)
    expect(panel.at_css('[data-supplier-documents-target="previewContent"]')['class']).to include('hidden')
    expect(panel.at_css('[data-supplier-documents-target="previewEmpty"]')['class']).to include('hidden')
    expect(panel['data-supplier-documents-range-label-value']).to include('Showing', 'documents')
    expect(panel.css('button[data-action="supplier-documents#select"][aria-pressed="false"]').size).to eq(2)
    dialog = panel.at_css('[data-supplier-documents-target="dialog"]')
    expect(dialog['class']).to include('fixed', 'hidden')
    expect(dialog.at_css('aside[role="dialog"][aria-modal="true"]')).to be_present
    expect(dialog.at_css('button[data-supplier-documents-target="closeButton"]')).to be_present
    expect(panel.at_css('[data-supplier-documents-target="list"]')['class']).not_to include('xl:grid-cols')
    expect(panel.css('article[data-supplier-documents-target="card"] button[data-action]').size).to eq(2)
    expect(panel.css('select[data-supplier-documents-target="categorySelect"] option').size).to eq(7)
  end

  it 'uploads files with valid metadata and redirects to the Documents section' do
    post admin_supplier_documents_path(supplier), params: { document: {
      file: upload, category: 'contract', description: 'Signed supply agreement'
    } }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(supplier.documents.attachments.count).to eq(1)
    expect(supplier.supplier_documents.first).to have_attributes(
      category: 'contract', description: 'Signed supply agreement', status: 'active',
      uploaded_by_id: user.id
    )
  end

  it 'uploads several documents in one request and retains their metadata' do
    post admin_supplier_documents_path(supplier), params: { document: {
      files: [upload('contract-one.pdf'), upload('contract-two.pdf')],
      category: 'contract', description: 'Multiple agreements'
    } }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(supplier.reload.documents.attachments.count).to eq(2)
    expect(supplier.documents.blobs.map { |blob| blob.filename.to_s })
      .to contain_exactly('contract-one.pdf', 'contract-two.pdf')
    expect(supplier.supplier_documents.pluck(:description)).to all(eq('Multiple agreements'))
  end

  it 'rejects an entire batch when any file is disallowed' do
    post admin_supplier_documents_path(supplier), params: { document: {
      files: [upload('valid.pdf'), upload('unsafe.html', 'text/html')], category: 'other'
    } }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(supplier.documents.attachments.count).to eq(0)
  end

  it 'rejects malformed upload lists' do
    post admin_supplier_documents_path(supplier), params: { document: { files: ['bad-value'] } }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(supplier.documents.attachments.count).to eq(0)
  end

  it 'rejects disallowed file formats or files above the size limit' do
    post admin_supplier_documents_path(supplier), params: { document: {
      file: upload('script.html', 'text/html'), category: 'other'
    } }
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(supplier.documents.attachments.count).to eq(0)
  end

  it 'updates document information without replacing its blob' do
    supplier.documents.attach(upload)
    original_id = attachment.id

    patch admin_supplier_document_update_path(supplier, document_id: original_id),
          params: { document: { category: 'fiscal', status: 'inactive', description: 'Updated certificate' } }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(attachment.reload.id).to eq(original_id)
    expect(supplier.supplier_documents.find_by!(attachment_id: original_id)).to have_attributes(
      category: 'fiscal', status: 'inactive', description: 'Updated certificate',
      updated_by_id: user.id
    )
  end

  it 'replaces a document without removing other attachments' do
    supplier.documents.attach(upload('old-contract.pdf'))
    original_id = attachment.id
    supplier.documents.attach(upload('untouched.pdf'))
    other_id = attachment.id

    patch admin_supplier_document_update_path(supplier, document_id: original_id),
          params: { document: { file: upload('replacement.pdf') } }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(flash[:notice]).to eq('Document replaced successfully.')
    supplier.reload
    expect(supplier.documents.attachments.pluck(:id)).to include(original_id, other_id)
    expect(supplier.supplier_documents.visible.map { |record| record.attachment.blob.filename.to_s })
      .to contain_exactly('untouched.pdf', 'replacement.pdf')
    expect(supplier.supplier_documents.find_by!(attachment_id: original_id)).not_to be_current_version
  end

  it 'previews only allowed inline types and forces downloads otherwise' do
    supplier.documents.attach(upload)
    pdf_id = attachment.id
    supplier.documents.attach(upload('notes.txt', 'text/plain'))
    txt_id = attachment.id
    docx = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('Word format placeholder'),
      filename: 'specification.docx',
      content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      identify: false
    )
    supplier.documents.attach(docx)
    docx_id = attachment.id

    get admin_supplier_document_preview_path(supplier, document_id: pdf_id)
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('inline')
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    expect(response.headers['Content-Security-Policy']).to eq("frame-ancestors 'self'")
    expect(response.headers['Content-Security-Policy']).not_to include('sandbox')

    get admin_supplier_document_preview_path(supplier, document_id: txt_id)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/plain')
    expect(response.body).to include('Plain text supplier note')
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')

    get admin_supplier_document_preview_path(supplier, document_id: docx_id)
    expect(response).to have_http_status(:unsupported_media_type)

    get admin_supplier_document_download_path(supplier, document_id: txt_id)
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('attachment')
  end

  it 'previews valid Office attachments as safe plain text for the slide-out drawer' do
    {
      'sample.docx' => [SupplierDemoDocumentOffice.docx_for(supplier),
                        Suppliers::DocumentContentPreview::DOCX_TYPE, 'DEMO'],
      'sample.xlsx' => [SupplierDemoDocumentOffice.xlsx_for(supplier),
                        Suppliers::DocumentContentPreview::XLSX_TYPE, 'Proveedor']
    }.each do |filename, (content, mime, expected)|
      office = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(content), filename:, content_type: mime, identify: false
      )
      supplier.documents.attach(office)
      id = supplier.documents.attachments.order(:id).last.id

      get admin_supplier_document_preview_path(supplier, document_id: id)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/plain')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
      expect(response.body).to include(expected)
    end
  end

  it 'retains deleted documents in the recoverable trash with their owner and history' do
    post admin_supplier_documents_path(supplier), params: {
      document: { file: upload('signed.pdf'), category: 'contract' }
    }
    id = supplier.documents.attachments.last.id

    delete admin_supplier_document_path(supplier, document_id: id)
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    trashed = supplier.supplier_documents.trashed.find_by!(attachment_id: id)
    expect(trashed.deleted_by_id).to eq(user.id)
    expect(supplier.documents.attachments.exists?(id)).to be(true)

    patch restore_admin_supplier_document_path(supplier, document_id: id)
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'documents'))
    expect(trashed.reload.deleted_at).to be_nil

    get admin_supplier_document_history_path(supplier, document_id: id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('signed.pdf')
  end

  it 'prevents access to another organizations documents' do
    outsider = create(:supplier, organization: create(:organization))
    outsider.documents.attach(upload)
    document_id = outsider.documents.attachments.first.id

    get admin_supplier_document_preview_path(outsider, document_id:)
    expect(response).to have_http_status(:not_found)
    sign_in user

    patch admin_supplier_document_update_path(outsider, document_id:),
          params: { document: { category: 'legal' } }
    expect(response).to have_http_status(:not_found)
    sign_in user

    post admin_supplier_documents_path(outsider), params: { document: { file: upload } }
    expect(response).to have_http_status(:not_found)
  end

  it 'blocks document modifications without manage permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:manage_documents?).and_return(false)
    post admin_supplier_documents_path(supplier), params: { document: { file: upload } }
    expect(response).to have_http_status(:forbidden).or redirect_to(admin_suppliers_path)
    expect(supplier.documents.attachments).to be_empty
  end
end
