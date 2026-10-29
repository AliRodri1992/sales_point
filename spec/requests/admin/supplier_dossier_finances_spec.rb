# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier financial statement and bank accounts', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def panel(section)
    Nokogiri::HTML(response.body).at_css("section[data-section='#{section}']")
  end

  def payable_for(amount:, due_on:, folio:, supplier_record: supplier)
    invoice = SupplierInvoice.create!(
      organization:, supplier: supplier_record, currency: supplier_record.currency, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on:,
      subtotal: amount, total: amount, tax_amount: 0, discount: 0, status: :posted, folio:
    )
    AccountPayable.create!(organization:, supplier: supplier_record, supplier_invoice: invoice, amount:, due_on:)
  end

  it 'renders separate supplier statement and bank account panels with empty illustrations' do
    get admin_supplier_path(supplier, tab: 'statement')

    expect(response).to have_http_status(:ok)
    expect(panel('statement').at_css('[data-finance-empty-payables] img[src*="saccountspayable"]')).to be_present
    expect(panel('statement').at_css('[data-finance-bank-accounts]')).to be_nil
    expect(panel('statement').css('a')).to be_empty
    expect(panel('statement').text).not_to include('Manage payables')
    expect(panel('bank_accounts').at_css('[data-finance-empty-banks]')).to be_present
    expect(panel('bank_accounts').at_css('[data-finance-bank-add-tile]')).to be_nil
    expect(panel('bank_accounts').at_css('[data-finance-bank-cards]')).to be_present
    header = panel('bank_accounts').at_css('[data-finance-banks-header]')
    heading_row = header.at_css('[data-finance-banks-heading-row]')
    manage_link = "a[href='#{admin_supplier_bank_accounts_path(supplier)}']"
    expect(heading_row.at_css('h2')).to be_present
    expect(heading_row.at_css(manage_link)).to be_nil
    expect(header.at_css(manage_link)).to be_nil
    search_row = panel('bank_accounts').at_css('[data-finance-banks-search-row]')
    expect(search_row.at_css('#dossier-banks-search')).to be_present
    expect(search_row.at_css(manage_link)).to be_present
    expect(panel('bank_accounts').css(manage_link).size).to eq(1)
    expect(panel('bank_accounts').at_css("a[href='#{admin_supplier_bank_accounts_path(supplier)}']")).to be_present
    expect(panel('bank_accounts').at_css('input[type="hidden"][name="banks_status"][value="active"]')).to be_present
    expect(panel('bank_accounts').at_css('input[type="hidden"][name="banks_bank"]')).to be_present
    expect(panel('bank_accounts').at_css('[data-finance-bank-status-tabs] a[aria-current="page"]')).to be_present
    expect(panel('bank_accounts').css('input[type="radio"]')).to be_empty
    expect(panel('bank_accounts').at_css('[data-finance-payables]')).to be_nil
  end

  it 'shows real outstanding and overdue amounts and the next due date' do
    payable_for(amount: 150, due_on: Date.current - 1.day, folio: 'INV-OLD')
    payable_for(amount: 70, due_on: Date.current + 5.days, folio: 'INV-SOON')

    get admin_supplier_path(supplier, tab: 'statement')

    statement = panel('statement')
    expect(statement.at_css('[data-finance-metric="balance"]').text).to include('220', supplier.currency.code)
    expect(statement.at_css('[data-finance-metric="overdue_balance"]').text).to include('150', supplier.currency.code)
    expect(statement.at_css('[data-finance-metric="pending_invoices"]').text.strip).to eq('2')
    formatted_due = I18n.with_locale(:en) { I18n.l(Date.current + 5.days) }
    expect(statement.at_css('[data-finance-metric="next_due"]').text).to include(formatted_due)
    expect(statement.text).to include('INV-OLD', 'INV-SOON')
    expect(statement.at_css('[data-finance-empty-payables]')).to be_nil
    expect(statement.text).not_to include('Manage payables')
  end

  it 'never includes invoices from a different supplier in the statement' do
    other = create(:supplier, organization:)
    payable_for(amount: 100, due_on: Date.current + 3.days, folio: 'OWN-001')
    payable_for(supplier_record: other, amount: 900, due_on: Date.current + 3.days, folio: 'OTHER-001')

    get admin_supplier_path(supplier, tab: 'statement')

    expect(panel('statement').text).to include('OWN-001')
    expect(panel('statement').text).not_to include('OTHER-001')
    expect(panel('statement').at_css('[data-finance-metric="pending_invoices"]').text.strip).to eq('1')
  end

  it 'retains the financial summary even when all balances are settled' do
    payable = payable_for(amount: 100, due_on: Date.current + 2.days, folio: 'PAID-001')
    payment = SupplierPayment.create!(
      organization:, supplier:, currency: supplier.currency, created_by: user,
      paid_on: Date.current, amount: 100, status: :posted
    )
    SupplierPaymentAllocation.create!(
      organization:, supplier_payment: payment, account_payable: payable, amount: 100
    )

    get admin_supplier_path(supplier, tab: 'statement')

    expect(panel('statement').at_css('[data-finance-empty-payables]')).to be_nil
    expect(panel('statement').text).to include('No pending payables')
    expect(panel('statement').at_css('[data-finance-metric="pending_invoices"]').text.strip).to eq('0')
  end

  it 'keeps sensitive bank data masked and hides archived accounts' do
    bank = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Delta Bank', holder_name: 'Supplier',
      account_number: '123456789012', currency_code: 'MXN', primary: true
    )
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Archived Bank', holder_name: 'Supplier',
      account_number: '999987654321', currency_code: 'MXN', deleted_at: Time.current
    )

    get admin_supplier_path(supplier, tab: 'bank_accounts')

    cards = panel('bank_accounts').css('[data-supplier-bank-accounts-target="card"]')
    expect(cards.length).to eq(1)
    expect(cards.first.text).to include('Delta Bank', bank.masked_number)
    expect(cards.first.text).not_to include('MXN', 'Supplier')
    expect(panel('bank_accounts').text).not_to include('Archived Bank', '123456789012', '999987654321')
    expect(panel('bank_accounts').at_css('[data-finance-bank-add-tile]')).to be_nil
    heading_row = panel('bank_accounts').at_css('[data-finance-banks-heading-row]')
    expect(heading_row.at_css('h2')).to be_present
    expect(heading_row.at_css("a[href='#{admin_supplier_bank_accounts_path(supplier)}']")).to be_nil
    search_row = panel('bank_accounts').at_css('[data-finance-banks-search-row]')
    expect(search_row.at_css("a[href='#{admin_supplier_bank_accounts_path(supplier)}']")).to be_present
  end

  it 'reuses the bank card design, hiding bank names when a logo exists' do
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'BBVA México', holder_name: 'Secret Account Holder',
      account_number: '123456789012', currency_code: 'MXN', primary: true,
      card_number: '4111111111111111'
    )

    get admin_supplier_path(supplier, tab: 'bank_accounts')

    cards = panel('bank_accounts').css('[data-supplier-bank-accounts-target="card"]')
    expect(cards.size).to eq(1)
    expect(cards.first.text).to include('BBVA', bank.masked_number)
    expect(cards.first.text).not_to include('BBVA México', 'Secret Account Holder', 'MXN', '123456789012')
    expect(cards.first.at_css('[title="Primary"]')).to be_present
    expect(cards.first.at_css('summary[aria-label^="Bank account actions:"]')).to be_present
    expect(panel('bank_accounts').at_css('[data-finance-bank-add-tile]')).to be_nil
    expect(panel('bank_accounts').css('button[data-option-value="BBVA México"]').size).to eq(1)
  end

  it 'shows archived accounts only on their status tab and permits their recovery' do
    original = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Archived Bank', holder_name: 'Supplier',
      account_number: '999987654321', currency_code: 'MXN', deleted_at: Time.current
    )

    get admin_supplier_path(supplier, tab: 'bank_accounts')
    expect(panel('bank_accounts').css('[data-supplier-bank-accounts-target="card"]')).to be_empty

    get admin_supplier_path(supplier, tab: 'bank_accounts', banks_status: 'archived')
    cards = panel('bank_accounts').css('[data-supplier-bank-accounts-target="card"]')
    expect(cards.size).to eq(1)
    expect(cards.first.text).to include('Archived Bank', 'Inactive')
    expect(cards.first.at_css("form[action$='/bank_accounts/#{original.id}/restore']")).to be_present
    expect(panel('bank_accounts').at_css('[data-finance-bank-add-tile]')).to be_nil
    expect(panel('bank_accounts').text).not_to include('999987654321')
  end

  it 'filters bank cards within the supplier and keeps the dossier tab selected' do
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'BBVA México', holder_name: 'Supplier',
      account_number: '112233440001', currency_code: 'MXN'
    )
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Santander', holder_name: 'Supplier',
      account_number: '998877660002', currency_code: 'MXN'
    )

    get admin_supplier_path(supplier, tab: 'bank_accounts', banks_bank: 'BBVA México')

    cards = panel('bank_accounts').css('[data-supplier-bank-accounts-target="card"]')
    expect(cards.size).to eq(1)
    expect(cards.first.text).to include('BBVA')
    expect(cards.first.text).not_to include('Santander')
    expect(Nokogiri::HTML(response.body).at_css('[data-controller="supplier-dossier"]')
      .attr('data-supplier-dossier-initial-tab-value')).to eq('bank_accounts')
  end

  it 'shows no add-bank tile for inactive suppliers' do
    supplier.update!(status: :inactive)
    get admin_supplier_path(supplier, tab: 'bank_accounts')

    expect(panel('bank_accounts').at_css('[data-finance-bank-add-tile]')).to be_nil
  end

  it 'opens the bank accounts panel when returning from bank account administration' do
    get admin_supplier_path(supplier, tab: 'bank_accounts')

    dossier = Nokogiri::HTML(response.body).at_css('[data-controller="supplier-dossier"]')
    expect(dossier['data-supplier-dossier-initial-tab-value']).to eq('bank_accounts')
    expect(panel('bank_accounts')).to be_present
    expect(panel('statement')).to be_present
  end

  it 'supports bookmarks to the old finances tab' do
    get admin_supplier_path(supplier, tab: 'finances')

    dossier = Nokogiri::HTML(response.body).at_css('[data-controller="supplier-dossier"]')
    expect(dossier['data-supplier-dossier-initial-tab-value']).to eq('statement')
  end
end
