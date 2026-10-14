# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Financial document edge cases', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user, :english) }
  let(:currency) { supplier.currency }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  def invoice
    SupplierInvoice.create!(
      organization:, supplier:, created_by: actor, currency:,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      subtotal: 100, total: 100
    )
  end

  def credit(supplier_record: supplier, amount: 50)
    SupplierCreditNote.create!(
      organization:, supplier: supplier_record, currency:, created_by: actor,
      issued_on: Date.current, total: amount
    )
  end

  def payable
    AccountsPayable::PostInvoice.call(invoice:, actor:)
  end

  it 'returns not found for missing private invoice PDF' do
    get download_pdf_admin_supplier_invoice_path(invoice)
    expect(response).to have_http_status(:not_found)
  end

  it 'returns not found for missing private invoice XML' do
    get download_xml_admin_supplier_invoice_path(invoice)
    expect(response).to have_http_status(:not_found)
  end

  it 'returns not found for missing private credit-note XML' do
    get download_xml_admin_supplier_credit_note_path(credit)
    expect(response).to have_http_status(:not_found)
  end

  it 'cannot post a credit note more than once' do
    record = credit
    post post_credit_admin_supplier_credit_note_path(record)
    expect(record.reload).to be_posted

    post post_credit_admin_supplier_credit_note_path(record)
    expect(response).to redirect_to(admin_supplier_credit_note_path(record))
    expect(record.reload).to be_posted
  end

  it 'cannot cancel an already allocated credit note' do
    debt = payable
    record = credit
    record.update!(status: :posted)
    AccountsPayable::ApplyCredit.call(credit_note: record, account_payable: debt, amount: 10, actor:)

    post cancel_admin_supplier_credit_note_path(record)

    expect(response).to redirect_to(admin_supplier_credit_note_path(record))
    expect(record.reload).to be_posted
    expect(record.available_amount).to eq(40)
  end

  it 'can cancel an unallocated posted credit note' do
    record = credit
    record.update!(status: :posted)

    post cancel_admin_supplier_credit_note_path(record)

    expect(response).to redirect_to(admin_supplier_credit_note_path(record))
    expect(record.reload).to be_cancelled
    expect(FinancialAuditEvent.where(event: 'credit.cancelled', subject_id: record.id)).to exist
  end

  it 'refuses to apply a credit note from another supplier' do
    debt = payable
    other_supplier = create(:supplier, organization:)
    other_credit = credit(supplier_record: other_supplier)
    other_credit.update!(status: :posted)

    post apply_admin_supplier_credit_note_path(other_credit), params: {
      account_payable_id: debt.id, amount: 10
    }

    expect(response).to redirect_to(admin_supplier_credit_note_path(other_credit))
    expect(other_credit.supplier_credit_allocations.count).to eq(0)
  end

  it 'refuses to apply a credit larger than the available debt' do
    debt = payable
    record = credit(amount: 200)
    record.update!(status: :posted)

    post apply_admin_supplier_credit_note_path(record), params: {
      account_payable_id: debt.id, amount: 150
    }

    expect(response).to redirect_to(admin_supplier_credit_note_path(record))
    expect(record.supplier_credit_allocations.count).to eq(0)
  end

  it 'does not allow cancellation of an invoice with a prior payment allocation' do
    record = invoice
    debt = AccountsPayable::PostInvoice.call(invoice: record, actor:)
    payment = SupplierPayment.create!(
      organization:, supplier:, currency:, created_by: actor, paid_on: Date.current, amount: 10
    )
    AccountsPayable::ApplyPayment.call(
      payment:, allocations: [{ account_payable_id: debt.id, amount: '10' }], actor:
    )

    post cancel_admin_supplier_invoice_path(record)

    expect(record.reload).to be_posted
    expect(response).to redirect_to(admin_supplier_invoice_path(record))
  end

  it 'reverses payment and leaves the ledger auditable' do
    debt = payable
    payment = SupplierPayment.create!(
      organization:, supplier:, currency:, created_by: actor, paid_on: Date.current, amount: 10
    )
    AccountsPayable::ApplyPayment.call(
      payment:, allocations: [{ account_payable_id: debt.id, amount: '10' }], actor:
    )

    post reverse_admin_supplier_payment_path(payment)

    expect(payment.reload).to be_reversed
    expect(debt.reload.balance).to eq(100)
    expect(FinancialAuditEvent.where(event: 'payment.reversed', subject_id: payment.id)).to exist
  end

  it 'archives bank accounts without disclosing private values' do
    account = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Example', holder_name: 'Vendor',
      account_number: '1234567890', currency_code: currency.code
    )

    delete admin_supplier_bank_account_path(supplier, account)

    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(account.reload.deleted_at).to be_present
    expect(FinancialAuditEvent.where(event: 'bank_account.archived', subject_id: account.id)).to exist
  end

  it 'reveal requests remain private and are audited' do
    account = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Example', holder_name: 'Vendor',
      account_number: '1234567890', currency_code: currency.code
    )

    post reveal_admin_supplier_bank_account_path(supplier, account)

    expect(response).to have_http_status(:ok)
    expect(response.headers['Cache-Control']).to eq('no-store')
    expect(response.parsed_body.fetch('account_number')).to eq('1234567890')
    expect(FinancialAuditEvent.where(event: 'bank_account.revealed', subject_id: account.id)).to exist
  end
end
