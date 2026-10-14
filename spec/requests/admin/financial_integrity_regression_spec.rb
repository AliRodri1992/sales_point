# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Financial integrity regression', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }
  let(:currency) { supplier.currency }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def invoice(total: 100, subtotal: 100, tax: 0)
    SupplierInvoice.create!(
      organization:, supplier:, currency:, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      subtotal:, tax_amount: tax, total:
    )
  end

  it 'rejects an inconsistent invoice total before creating a payable' do
    record = invoice(total: 130, subtotal: 100)

    post post_invoice_admin_supplier_invoice_path(record)

    expect(response).to redirect_to(admin_supplier_invoice_path(record))
    expect(record.reload).to be_draft
    expect(record.account_payable).to be_nil
  end

  it 'allows a one-cent rounding difference in invoice amounts' do
    record = invoice(total: 116.01, tax: 16)

    post post_invoice_admin_supplier_invoice_path(record)

    expect(record.reload).to be_posted
    expect(record.account_payable.amount).to eq(116.01)
  end

  it 'distinguishes cancelled from settled obligations on the financial dashboard' do
    record = invoice
    payable = AccountsPayable::PostInvoice.call(invoice: record, actor: user)
    AccountsPayable::CancelInvoice.call(invoice: record, actor: user)

    expect(payable.reload).not_to be_settled
    get admin_account_payables_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.accounts_payable.states.cancelled'))
    expect(response.body).to include(I18n.t('admin.accounts_payable.open_count'))
  end

  it 'lets a cashier choose a masked supplier bank account in the payment form' do
    bank = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Test bank',
      holder_name: 'Vendor', account_number: '12345678', currency_code: currency.code
    )

    get new_admin_supplier_payment_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="supplier-payment-bank"')
    expect(response.body).to include(bank.masked_number)
    expect(response.body).not_to include('12345678')
  end

  it 'rejects posting a payment using an archived bank account' do
    bank = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Test bank',
      holder_name: 'Vendor', account_number: '12345678', currency_code: currency.code
    )
    bank.update!(deleted_at: Time.current)
    expect(bank.reload.deleted_at).to be_present
    expect(SupplierBankAccount.active.where(id: bank.id)).to be_empty

    payment = SupplierPayment.new(
      organization:, supplier:, currency:, created_by: user, supplier_bank_account_id: bank.id,
      paid_on: Date.current, amount: 25
    )
    expect(payment).not_to be_valid

    post admin_supplier_payments_path, params: {
      supplier_payment: {
        supplier_id: supplier.id, currency_id: currency.id, supplier_bank_account_id: bank.id,
        paid_on: Date.current, amount: 25
      }
    }

    expect(response.status).to eq(422), "Redirect: #{response.location}; payment IDs: #{SupplierPayment.pluck(:id).inspect}"
  end

  it 'rejects supplier bank account in another currency' do
    bank = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Test bank',
      holder_name: 'Vendor', account_number: '12345678', currency_code: 'USD'
    )
    post admin_supplier_payments_path, params: {
      supplier_payment: {
        supplier_id: supplier.id, currency_id: currency.id, supplier_bank_account_id: bank.id,
        paid_on: Date.current, amount: 25
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'audits invoice edits' do
    record = invoice

    patch admin_supplier_invoice_path(record), params: {
      supplier_invoice: { supplier_id: supplier.id, currency_id: currency.id,
                          folio: 'NEW-FOLIO' }
    }

    expect(response).to redirect_to(admin_supplier_invoice_path(record))
    expect(FinancialAuditEvent.where(event: 'invoice.updated', subject_id: record.id)).to exist
  end
end
