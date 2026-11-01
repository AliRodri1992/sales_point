# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe 'Supplier document authorization', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:role) { create(:system_role, :system, code: 'administrator') }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: role)
    sign_in user
  end

  def attach_document(record)
    record.documents.attach(
      io: StringIO.new('%PDF-1.4 test document'),
      filename: 'invoice.pdf',
      content_type: 'application/pdf'
    )
    record.documents.attachments.last
  end

  it 'downloads documents belonging to the current organization' do
    attachment = attach_document(supplier)

    get admin_supplier_document_download_path(supplier, document_id: attachment.id)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/pdf')
    expect(response.body).to include('%PDF-1.4')
  end

  it 'does not allow a create-only document role to download existing files' do
    attachment = attach_document(supplier)
    limited_user = create(:user)
    create(:organization_membership, user: limited_user, organization:)
    limited_role = create(:system_role, role_type: :system, code: 'supplier_docs_writer')
    limited_role.permissions << create(
      :permission, code: 'suppliers.documents.create', module_name: 'Proveedores'
    )
    create(:user_role, user: limited_user, system_role: limited_role)
    sign_in limited_user

    get admin_supplier_document_download_path(supplier, document_id: attachment.id)
    expect(response).not_to have_http_status(:ok)

    get admin_supplier_document_preview_path(supplier, document_id: attachment.id)
    expect(response).not_to have_http_status(:ok)
  end

  it 'rejects attempts to download a foreign organization document' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    attachment = attach_document(foreign_supplier)

    get admin_supplier_document_download_path(foreign_supplier, document_id: attachment.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'does not delete a document from another supplier' do
    attachment = attach_document(create(:supplier, organization:))

    delete admin_supplier_document_path(supplier, document_id: attachment.id)

    expect(response).to have_http_status(:not_found)
    expect(ActiveStorage::Attachment.exists?(attachment.id)).to be(true)
  end

  it 'responds with not found for a document whose storage blob is unavailable' do
    attachment = attach_document(supplier)
    allow_any_instance_of(ActiveStorage::Attachment).to receive(:blob).and_return(nil)

    get admin_supplier_document_preview_path(supplier, document_id: attachment.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'refuses inline previews of unsupported HTML documents' do
    attachment = attach_document(supplier)
    attachment.blob.update!(content_type: 'text/html', filename: 'unsafe.html')

    get admin_supplier_document_preview_path(supplier, document_id: attachment.id)

    expect(response).to have_http_status(:unsupported_media_type)
  end

  it 'does not render legacy Office documents when the PDF converter is unavailable' do
    attachment = attach_document(supplier)
    attachment.blob.update!(content_type: 'application/msword', filename: 'supplier.doc')
    allow(Suppliers::OfficeDocumentPdf).to receive(:available?).and_return(false)

    get admin_supplier_document_preview_path(supplier, document_id: attachment.id)

    expect(response).to have_http_status(:unsupported_media_type)
  end

  it 'does not disclose documents without a current organization' do
    attachment = attach_document(supplier)
    allow_any_instance_of(Admin::SupplierDocumentsController).to receive(:current_organization).and_return(nil)

    get admin_supplier_document_download_path(supplier, document_id: attachment.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'refuses downloads when an attachment has lost its storage blob' do
    attachment = attach_document(supplier)
    allow_any_instance_of(ActiveStorage::Attachment).to receive(:blob).and_return(nil)

    get admin_supplier_document_download_path(supplier, document_id: attachment.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'redirects a create-only uploader to the masked supplier list instead of the document dossier' do
    limited_user = create(:user)
    create(:organization_membership, user: limited_user, organization:)
    limited_role = create(:system_role, :system, code: 'supplier_docs_upload_only')
    limited_role.permissions << create(:permission, code: 'suppliers.documents.create',
                                                      module_name: 'Proveedores')
    create(:user_role, user: limited_user, system_role: limited_role)
    sign_in limited_user

    Tempfile.create(['supplier-upload', '.pdf']) do |tempfile|
      tempfile.write('%PDF-1.4 supplier document')
      tempfile.flush
      upload = Rack::Test::UploadedFile.new(tempfile.path, 'application/pdf')

      post admin_supplier_documents_path(supplier), params: { document: { file: upload } }
    end

    expect(response).to redirect_to(admin_suppliers_path)
    expect(supplier.supplier_documents.visible.count).to eq(1)
  end
end
