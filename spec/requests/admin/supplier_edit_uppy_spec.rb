# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier edit Uppy document uploader', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  after { @upload_file&.close! }

  def document_file(filename = 'agreement.pdf', content_type = 'application/pdf')
    @upload_file = Tempfile.new(['edit-uppy', '.pdf'])
    @upload_file.write('%PDF-1.4 sample document')
    @upload_file.rewind
    Rack::Test::UploadedFile.new(@upload_file.path, content_type, original_filename: filename)
  end

  it 'shows the branded Uppy upload component only when editing a provider' do
    get edit_admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    editor = document.at_css('[data-controller="supplier-edit-uppy"]')
    expect(editor).to be_present
    expect(editor['data-supplier-edit-uppy-url-value']).to eq(admin_supplier_documents_path(supplier))
    expect(editor.at_css('[data-supplier-edit-uppy-target="dashboard"]')).to be_present
    expect(editor.at_css('select[data-supplier-edit-uppy-target="category"]')).to be_present
    expect(document.at_css('input[name="supplier[documents][]"]')).to be_nil
    expect(document.at_css('link[href*="uppy.min.css"]')).to be_present
  end

  it 'renders the edit uploader entirely with original SVG icons' do
    get edit_admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    uploader = document.at_css('[data-controller="supplier-edit-uppy"]')
    expect(uploader.css('svg').size).to be >= 3
    expect(uploader.at_css('svg circle')).to be_present
    expect(uploader.css('[data-rails-icons]')).to be_empty
  end

  it 'presents a single dropzone without an extra dashed upload shell' do
    get edit_admin_supplier_path(supplier)

    document = Nokogiri::HTML(response.body)
    editor = document.at_css('[data-controller="supplier-edit-uppy"]')
    dashboard = editor.at_css('[data-supplier-edit-uppy-target="dashboard"]')
    retry_button = editor.at_css('[data-supplier-edit-uppy-target="retryButton"]')

    expect(editor.css('[data-supplier-edit-uppy-target="dashboard"]').size).to eq(1)
    expect(dashboard['class']).not_to include('border-dashed')
    expect(dashboard.at_css('[data-supplier-edit-uppy-target="placeholder"]')['class']).not_to include('border-dashed')
    expect(retry_button['hidden']).not_to be_nil
    expect(editor.css('input[type="file"]')).to be_empty
    expect(editor.css('[data-supplier-edit-uppy-target="fallback"]')).to be_empty
  end

  it 'keeps upload completion feedback below the only Uppy dashboard' do
    get edit_admin_supplier_path(supplier)

    document = Nokogiri::HTML(response.body)
    editor = document.at_css('[data-controller="supplier-edit-uppy"]')
    dashboard = editor.at_css('[data-supplier-edit-uppy-target="dashboard"]')
    feedback = editor.at_css('[data-supplier-edit-uppy-target="status"]')

    expect(feedback).to be_present
    expect(feedback['hidden']).not_to be_nil
    expect(feedback['role']).to eq('status')
    expect(feedback.at_css('[data-supplier-edit-uppy-target="statusMessage"]')).to be_present
    expect(feedback.ancestors).not_to include(dashboard)
    expect(dashboard.next_element).not_to eq(feedback)
    expect(editor.css('[data-supplier-edit-uppy-target="dashboard"]').length).to eq(1)
  end

  it 'preserves the original new supplier file input' do
    get new_admin_supplier_path

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[data-controller="supplier-edit-uppy"]')).to be_nil
    expect(document.at_css('input[type="file"][name="supplier[documents][]"]')).to be_present
    expect(document.at_css('link[href*="uppy.min.css"]')).to be_nil
  end

  it 'does not replace the document uploader on the supplier show screen' do
    get admin_supplier_path(supplier, tab: 'documents')

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[data-controller="supplier-edit-uppy"]')).to be_nil
    expect(document.at_css('form[data-supplier-documents-target="uploadForm"]')).to be_present
    expect(document.at_css('link[href*="uppy.min.css"]')).to be_nil
  end

  it 'responds with JSON and creates a tracked Active Storage attachment for Uppy uploads' do
    post admin_supplier_documents_path(supplier),
         params: { document: { file: document_file, category: 'contract', description: 'Signed agreement' } },
         headers: { 'ACCEPT' => 'application/json' }

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('status' => 'ok', 'uploaded' => 1)
    uploaded = supplier.supplier_documents.visible.first
    expect(uploaded).to have_attributes(category: 'contract', description: 'Signed agreement')
    expect(uploaded.attachment.blob.filename.to_s).to eq('agreement.pdf')
  end

  it 'preserves Uppy uploads when the remaining supplier edits are saved' do
    post admin_supplier_documents_path(supplier),
         params: { document: { file: document_file, category: 'contract' } },
         headers: { 'ACCEPT' => 'application/json' }

    expect(response).to have_http_status(:created)
    attachment_id = supplier.reload.supplier_documents.visible.last.attachment_id

    patch admin_supplier_path(supplier), params: { supplier: { name: 'Updated company name' } }

    expect(response).to have_http_status(:redirect)
    expect(supplier.reload.name).to eq('Updated company name')
    expect(supplier.documents.attachments.pluck(:id)).to include(attachment_id)
    expect(supplier.supplier_documents.visible.pluck(:attachment_id)).to include(attachment_id)
  end

  it 'returns a structured validation error when a document is unsupported' do
    post admin_supplier_documents_path(supplier),
         params: { document: { file: document_file('not-a-pdf.pdf', 'text/html') } },
         headers: { 'ACCEPT' => 'application/json' }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to have_key('error')
    expect(supplier.documents.attachments.count).to eq(0)
  end
end
