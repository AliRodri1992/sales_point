# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier invoice creation and edit error paths', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user, :english) }
  let(:currency) { supplier.currency }

  before do
    create(:organization_membership, organization:, user: actor)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  def invoice
    SupplierInvoice.create!(
      organization:, supplier:, currency:, created_by: actor,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      subtotal: 40, total: 40
    )
  end

  def params_for_invoice(extra = {})
    {
      supplier_id: supplier.id, currency_id: currency.id, total: 40, subtotal: 40,
      received_on: Date.current, issued_on: Date.current, due_on: Date.tomorrow
    }.merge(extra)
  end

  def invalid_xml
    Rack::Test::UploadedFile.new(
      StringIO.new('<InvalidInvoice />'), 'application/xml', original_filename: 'invalid.xml'
    )
  end

  it 'renders the draft invoice edit form' do
    get edit_admin_supplier_invoice_path(invoice)
    expect(response).to have_http_status(:ok)
  end

  it 'rejects invoice with invalid supplier on creation' do
    post admin_supplier_invoices_path, params: {
      supplier_invoice: params_for_invoice(supplier_id: 0)
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(SupplierInvoice.count).to eq(0)
  end

  it 'rejects invoice with negative amount on creation' do
    post admin_supplier_invoices_path, params: {
      supplier_invoice: params_for_invoice(total: -10)
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(SupplierInvoice.count).to eq(0)
  end

  it 'rejects malformed XML on invoice creation' do
    post admin_supplier_invoices_path, params: {
      supplier_invoice: params_for_invoice(xml_document: invalid_xml)
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(SupplierInvoice.count).to eq(0)
  end

  it 'rejects cross-tenant supplier on update without mutating invoice' do
    record = invoice
    patch admin_supplier_invoice_path(record), params: {
      supplier_invoice: params_for_invoice(supplier_id: 0)
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.supplier).to eq(supplier)
  end

  it 'rejects negative total on invoice update' do
    record = invoice
    patch admin_supplier_invoice_path(record), params: {
      supplier_invoice: params_for_invoice(total: -10)
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.total).to eq(40)
  end

  it 'rejects malformed CFDI on invoice update' do
    record = invoice
    patch admin_supplier_invoice_path(record), params: {
      supplier_invoice: params_for_invoice(xml_document: invalid_xml)
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.xml_document).not_to be_attached
  end

  it 'rejects receipt reconciliation with unknown receipt IDs' do
    record = invoice
    post match_receipts_admin_supplier_invoice_path(record), params: { receipt_ids: [999_999] }
    expect(response).to redirect_to(admin_supplier_invoice_path(record))
    expect(record.supplier_invoice_receipts.count).to eq(0)
  end

  it 'does not allow editing an already posted invoice' do
    record = invoice
    AccountsPayable::PostInvoice.call(invoice: record, actor:)
    get edit_admin_supplier_invoice_path(record)
    expect(response).to have_http_status(:forbidden)
  end
end
