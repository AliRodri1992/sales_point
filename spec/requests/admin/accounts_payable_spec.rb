# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accounts payable finance screens', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }
  let(:currency) { supplier.currency }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def invoice_attributes(total: '100.00')
    {
      supplier_id: supplier.id, currency_id: currency.id, folio: 'FACT-001',
      issued_on: Date.current, received_on: Date.current,
      due_on: Date.current + 30.days,
      subtotal: total, total:, tax_amount: 0, discount: 0
    }
  end

  def create_invoice
    post admin_supplier_invoices_path, params: { supplier_invoice: invoice_attributes }
    SupplierInvoice.order(:id).last
  end

  def posted_invoice
    invoice = create_invoice
    post post_invoice_admin_supplier_invoice_path(invoice)
    invoice.reload
  end

  it 'renders the finance dashboards with no records' do
    get admin_account_payables_path
    expect(response).to have_http_status(:ok)
    get admin_supplier_invoices_path
    expect(response).to have_http_status(:ok)
    get admin_supplier_payments_path
    expect(response).to have_http_status(:ok)
    get admin_supplier_credit_notes_path
    expect(response).to have_http_status(:ok)
  end

  it 'renders forms for invoices, payments, credits and bank accounts' do
    get new_admin_supplier_invoice_path
    expect(response).to have_http_status(:ok)
    get new_admin_supplier_payment_path
    expect(response).to have_http_status(:ok)
    get new_admin_supplier_credit_note_path
    expect(response).to have_http_status(:ok)
    get new_admin_supplier_bank_account_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'creates an invoice, edits a draft and posts exactly one payable' do
    invoice = create_invoice
    expect(response).to redirect_to(admin_supplier_invoice_path(invoice))
    expect(invoice).to be_draft

    get edit_admin_supplier_invoice_path(invoice)
    expect(response).to have_http_status(:ok)
    patch admin_supplier_invoice_path(invoice), params: {
      supplier_invoice: invoice_attributes.merge(folio: 'FACT-002')
    }
    expect(response).to redirect_to(admin_supplier_invoice_path(invoice))
    expect(invoice.reload.folio).to eq('FACT-002')

    post post_invoice_admin_supplier_invoice_path(invoice)
    expect(response).to redirect_to(admin_supplier_invoice_path(invoice))
    expect(invoice.reload).to be_posted
    expect(invoice.account_payable.balance).to eq(100)

    get admin_account_payable_path(invoice.account_payable)
    expect(response).to have_http_status(:ok)
    get admin_supplier_invoice_path(invoice)
    expect(response).to have_http_status(:ok)
  end

  it 'keeps payable and invoice screens available when the currency association is missing' do
    invoice = posted_invoice
    allow_any_instance_of(SupplierInvoice).to receive(:currency).and_return(nil)

    get admin_account_payable_path(invoice.account_payable)
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('[data-payable-currency]').text).to eq('—')

    get admin_account_payables_path
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('table tbody').text).to include('—')

    get admin_supplier_invoice_path(invoice)
    expect(response).to have_http_status(:ok)
  end

  it 'keeps the supplier statement available when an invoice currency association is missing' do
    invoice = posted_invoice
    allow_any_instance_of(SupplierInvoice).to receive(:currency).and_return(nil)

    get admin_supplier_path(supplier, tab: 'statement')
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('[data-finance-payables]')).to be_present
  end

  it 'records explicit account review and refuses verification through ordinary updates' do
    account = supplier.supplier_bank_accounts.create!(
      organization:, holder_name: 'Vendor', bank_name: 'Demo',
      clabe: '032180000118359719', currency_code: 'MXN'
    )
    patch admin_supplier_bank_account_path(supplier, account),
          params: { supplier_bank_account: { holder_name: 'New Owner', verification_status: 'verified' } }
    expect(account.reload.verification_status).to eq('pending')

    patch review_admin_supplier_bank_account_path(supplier, account), params: { decision: 'verified' }
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(account.reload.verification_status).to eq('verified')
    expect(account.verified_at).to be_present
    expect(FinancialAuditEvent.where(event: 'bank_account.verification_reviewed', subject: account)).to exist
  end

  it 'posts, applies and reverses a vendor payment' do
    invoice = posted_invoice
    payable = invoice.account_payable
    post admin_supplier_payments_path, params: {
      supplier_payment: {
        supplier_id: supplier.id, currency_id: currency.id,
        paid_on: Date.current, amount: '40.00', reference: 'TRX-123'
      }
    }
    payment = SupplierPayment.order(:id).last
    expect(response).to redirect_to(admin_supplier_payment_path(payment))

    get admin_supplier_payment_path(payment)
    expect(response).to have_http_status(:ok)

    post post_payment_admin_supplier_payment_path(payment),
         params: { allocations: [{ account_payable_id: payable.id, amount: '40.00' }] }
    expect(response).to redirect_to(admin_supplier_payment_path(payment))
    expect(payment.reload).to be_posted
    expect(payable.reload.balance).to eq(60)

    post reverse_admin_supplier_payment_path(payment)
    expect(response).to redirect_to(admin_supplier_payment_path(payment))
    expect(payment.reload).to be_reversed
    expect(payable.reload.balance).to eq(100)
  end

  it 'splits one payment across two invoices without exceeding either balance' do
    first_invoice = posted_invoice
    second_invoice = SupplierInvoice.create!(
      organization:, supplier:, currency:, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on: Date.current + 20.days,
      folio: 'FACT-SECOND', subtotal: 90, total: 90
    )
    second_payable = AccountsPayable::PostInvoice.call(invoice: second_invoice, actor: user)

    payment = SupplierPayment.create!(
      organization:, supplier:, currency:, created_by: user,
      paid_on: Date.current, amount: 110
    )

    post post_payment_admin_supplier_payment_path(payment), params: {
      allocations: [
        { account_payable_id: first_invoice.account_payable.id, amount: '40.00' },
        { account_payable_id: second_payable.id, amount: '70.00' },
        { account_payable_id: first_invoice.account_payable.id, amount: '' }
      ]
    }

    expect(response).to redirect_to(admin_supplier_payment_path(payment))
    expect(payment.reload).to be_posted
    expect(payment.supplier_payment_allocations.count).to eq(2)
    expect(first_invoice.account_payable.reload.balance).to eq(60)
    expect(second_payable.reload.balance).to eq(20)
  end

  it 'creates and allocates a credit note against a payable' do
    payable = posted_invoice.account_payable
    post admin_supplier_credit_notes_path, params: {
      supplier_credit_note: {
        supplier_id: supplier.id, currency_id: currency.id,
        issued_on: Date.current, total: '25.00', folio: 'NC-001'
      }
    }
    credit = SupplierCreditNote.order(:id).last
    expect(response).to redirect_to(admin_supplier_credit_note_path(credit))

    get admin_supplier_credit_note_path(credit)
    expect(response).to have_http_status(:ok)

    post post_credit_admin_supplier_credit_note_path(credit)
    expect(response).to redirect_to(admin_supplier_credit_note_path(credit))
    expect(credit.reload).to be_posted

    post apply_admin_supplier_credit_note_path(credit),
         params: { account_payable_id: payable.id, amount: '25.00' }
    expect(response).to redirect_to(admin_supplier_credit_note_path(credit))
    expect(payable.reload.balance).to eq(75)
  end

  it 'blocks cancellation when an invoice has financial allocations' do
    invoice = posted_invoice
    credit = SupplierCreditNote.create!(
      organization:, supplier:, currency:, created_by: user,
      issued_on: Date.current, total: 10, status: :posted
    )
    AccountsPayable::ApplyCredit.call(credit_note: credit, account_payable: invoice.account_payable,
                                      amount: 10, actor: user)

    post cancel_admin_supplier_invoice_path(invoice)
    expect(response).to redirect_to(admin_supplier_invoice_path(invoice))
    expect(invoice.reload).to be_posted
  end

  it 'creates and masks supplier bank account details' do
    post admin_supplier_bank_accounts_path(supplier), params: {
      supplier_bank_account: {
        holder_name: 'Vendor Holdings', bank_name: 'Example Bank',
        account_number: '1234567890', currency_code: 'MXN', primary: '1'
      }
    }
    account = supplier.supplier_bank_accounts.last
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(account.masked_number).to eq('•••• 7890')

    get admin_supplier_bank_accounts_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('1234567890')

    get edit_admin_supplier_bank_account_path(supplier, account)
    expect(response).to have_http_status(:ok)
    patch admin_supplier_bank_account_path(supplier, account), params: {
      supplier_bank_account: { holder_name: 'Updated Owner' }
    }
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(account.reload.holder_name).to eq('Updated Owner')

    post reveal_admin_supplier_bank_account_path(supplier, account)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('account_number')).to eq('1234567890')
    expect(FinancialAuditEvent.where(event: 'bank_account.revealed')).to exist
  end

  it 'rejects cross-organization access to every financial document type' do
    other = create(:supplier, organization: create(:organization))
    invoice = SupplierInvoice.create!(
      organization: other.organization, supplier: other, currency: other.currency,
      created_by: user, issued_on: Date.current, received_on: Date.current,
      due_on: Date.tomorrow, total: 100
    )
    AccountsPayable::PostInvoice.call(invoice:, actor: user)

    get admin_supplier_invoice_path(invoice)
    expect(response).to have_http_status(:not_found)

    # The integration test's 404 request clears the Warden session; reauthenticate
    # before checking the second independently protected endpoint.
    sign_in user
    get admin_account_payable_path(invoice.account_payable)
    expect(response).to have_http_status(:not_found)
  end

  it 'prevents a malformed XML document from creating invoices' do
    invalid_xml = Rack::Test::UploadedFile.new(
      StringIO.new('<!DOCTYPE x [<!ENTITY y SYSTEM "file:///etc/passwd">]><x/>'),
      'application/xml', original_filename: 'malicious.xml'
    )
    post admin_supplier_invoices_path, params: {
      supplier_invoice: invoice_attributes.merge(xml_document: invalid_xml)
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.supplier_invoices.count).to eq(0)
  end

  it 'does not allow downloading another organization invoice documents' do
    other = create(:supplier, organization: create(:organization))
    foreign = SupplierInvoice.create!(
      organization: other.organization, supplier: other, currency: other.currency,
      created_by: user, issued_on: Date.current, received_on: Date.current,
      due_on: Date.tomorrow, total: 150
    )

    get download_pdf_admin_supplier_invoice_path(foreign)
    expect(response).to have_http_status(:not_found)
  end

  it 'blocks an unauthenticated finance dashboard' do
    sign_out user
    get admin_account_payables_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
