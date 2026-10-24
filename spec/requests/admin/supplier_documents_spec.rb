# frozen_string_literal: true

require 'rails_helper'

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
end
