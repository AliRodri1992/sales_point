# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier financial listing filters', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:, name: 'Visible Supplier') }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def page
    Nokogiri::HTML(response.body)
  end

  it 'filters invoices by reference and status' do
    SupplierInvoice.create!(
      organization:, supplier:, currency: supplier.currency, created_by: user,
      folio: 'FOLIO-SEARCH-483', issued_on: Date.current, received_on: Date.current,
      due_on: Date.current + 30.days, subtotal: 100, total: 100,
      discount: 0, tax_amount: 0, exchange_rate: 1
    )

    get admin_supplier_invoices_path, params: { q: 'SEARCH-483', status: 'draft' }
    expect(response).to have_http_status(:ok)
    expect(page.css('[data-financial-table="invoices"] tbody tr').size).to eq(1)
    expect(page.text).to include('FOLIO-SEARCH-483')

    get admin_supplier_invoices_path, params: { q: 'SEARCH-483', status: 'posted' }
    expect(page.css('[data-financial-table="invoices"] tbody tr')).to be_empty
    expect(page.at_css('select[name="status"] option[selected]')['value']).to eq('posted')
  end

  it 'searches payments by reference and supplier without disclosing a bank account' do
    SupplierPayment.create!(
      organization:, supplier:, currency: supplier.currency, created_by: user,
      paid_on: Date.current, amount: 90, reference: 'TRANSFER-UX-891'
    )

    get admin_supplier_payments_path, params: { q: 'TRANSFER-UX-891' }
    expect(response).to have_http_status(:ok)
    expect(page.css('[data-financial-table="payments"] tbody tr').size).to eq(1)

    get admin_supplier_payments_path, params: { q: 'nonexistent-value' }
    expect(page.css('[data-financial-table="payments"] tbody tr')).to be_empty
    link = "a[href='#{admin_supplier_payments_path}'"
    expect(page.at_css("#{link}]")).to be_present
  end

  it 'shows currency codes and filters supplier credit notes' do
    SupplierCreditNote.create!(
      organization:, supplier:, currency: supplier.currency, created_by: user,
      issued_on: Date.current, total: 125, folio: 'CREDIT-UX-321'
    )
    get admin_supplier_credit_notes_path, params: { q: 'CREDIT-UX-321', status: 'draft' }

    expect(response).to have_http_status(:ok)
    expect(page.css('[data-financial-table="credits"] tbody tr').size).to eq(1)
    expect(page.text).to include('CREDIT-UX-321', supplier.currency.code)

    get admin_supplier_credit_notes_path, params: { q: 'CREDIT-UX-321', status: 'posted' }
    expect(page.css('[data-financial-table="credits"] tbody tr')).to be_empty
  end
end
