# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier dossier finances overview', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def finances
    Nokogiri::HTML(response.body).at_css('section[data-section="finances"]')
  end

  def posted_payable(amount:, due_on:, folio:)
    invoice = SupplierInvoice.create!(
      organization:, supplier:, currency: supplier.currency, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on:,
      subtotal: amount, total: amount, tax_amount: 0, discount: 0,
      status: :posted, folio:
    )
    AccountPayable.create!(organization:, supplier:, supplier_invoice: invoice, amount:, due_on:)
  end

  it 'renders both finance sections with empty states when no financial records exist' do
    get admin_supplier_path(supplier, tab: 'finances')

    expect(response).to have_http_status(:ok)
    expect(finances.at_css('[data-finance-payables]')).to be_present
    expect(finances.at_css('[data-finance-bank-accounts]')).to be_present
    expect(finances.text).to include('No payables registered yet', 'No bank accounts registered yet')
    expect(finances.at_css('[data-finance-empty-payables] img[src*="saccountspayable"]')).to be_present
    expect(finances.at_css('[data-finance-empty-banks] img[src*="sbankaccounts"]')).to be_present
    expect(finances.at_css('[data-finance-metric="invoices"]')).to be_nil
    expect(finances.css("a[href='#{admin_account_payables_path}']").size).to eq(1)
    expect(finances.css("a[href='#{admin_supplier_bank_accounts_path(supplier)}']").size).to eq(1)
  end

  it 'separates the accounts payable heading from its empty-state card' do
    get admin_supplier_path(supplier, tab: 'finances')

    wrapper = finances.at_css('[data-finance-payables]')
    expect(wrapper['class'].split).to include('space-y-2')
    header = wrapper.at_css('[data-finance-payables-header]')
    empty = wrapper.at_css('[data-finance-empty-payables]')

    expect(header.parent).to eq(wrapper)
    expect(empty.parent).to eq(wrapper)
    expect(header.text).not_to include('No payables registered yet')
    expect(empty.text).to include('No payables registered yet')
    expect(header['class']).to include('bg-white')
    expect(empty['class']).to include('bg-white')
  end

  it 'separates the bank accounts heading from its empty-state card' do
    get admin_supplier_path(supplier, tab: 'finances')

    wrapper = finances.at_css('[data-finance-bank-accounts]')
    expect(wrapper['class'].split).to include('space-y-2')
    header = wrapper.at_css('[data-finance-banks-header]')
    empty = wrapper.at_css('[data-finance-empty-banks]')

    expect(header.parent).to eq(wrapper)
    expect(empty.parent).to eq(wrapper)
    expect(header.text).not_to include('No bank accounts registered yet')
    expect(empty.text).to include('No bank accounts registered yet')
    expect(header['class']).to include('bg-white')
    expect(empty['class']).to include('bg-white')
  end

  it 'shows real invoice balances and due-date counters' do
    posted_payable(amount: 150, due_on: Date.current - 1.day, folio: 'INV-OLD')
    posted_payable(amount: 70, due_on: Date.current + 5.days, folio: 'INV-SOON')

    get admin_supplier_path(supplier, tab: 'finances')

    expect(finances.at_css('[data-finance-metric="invoices"]').text.strip).to eq('2')
    expect(finances.at_css('[data-finance-metric="balance"]').text).to include('220', supplier.currency.code)
    expect(finances.at_css('[data-finance-metric="upcoming"]').text.strip).to eq('1')
    expect(finances.at_css('[data-finance-metric="overdue"]').text.strip).to eq('1')
    expect(finances.text).to include('INV-OLD', 'INV-SOON', 'Overdue')
    expect(finances.at_css('[data-finance-empty-payables]')).to be_nil
    expect(finances.at_css('[data-finance-payables-content]')).to be_present
  end

  it 'shows the bank empty state when all existing accounts are archived' do
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Archived Bank',
      holder_name: 'Supplier', account_number: '999987654321',
      currency_code: 'MXN', deleted_at: Time.current
    )

    get admin_supplier_path(supplier, tab: 'finances')

    bank_section = finances.at_css('[data-finance-bank-accounts]')
    expect(bank_section.at_css('img[src*="sbankaccounts"]')).to be_present
    expect(bank_section.text).not_to include('Archived Bank', '999987654321')
  end

  it 'keeps accounts payable details when invoices exist but no balances remain open' do
    payable = posted_payable(amount: 100, due_on: Date.current + 2.days, folio: 'PAID-001')
    allow_any_instance_of(AccountPayable).to receive(:balance).and_return(0.to_d)

    get admin_supplier_path(supplier, tab: 'finances')

    expect(payable).to be_persisted
    expect(finances.at_css('[data-finance-empty-payables]')).to be_nil
    expect(finances.text).to include('No pending payables')
    expect(finances.at_css('[data-finance-metric="invoices"]').text.strip).to eq('1')
  end

  it 'shows only active bank accounts and never exposes unmasked numbers' do
    bank = SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Delta Bank',
      holder_name: 'Verifiable Supplier', account_number: '123456789012',
      currency_code: 'MXN', primary: true
    )
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Archived Bank',
      holder_name: 'Verifiable Supplier', account_number: '999987654321',
      currency_code: 'MXN', deleted_at: Time.current
    )

    get admin_supplier_path(supplier, tab: 'finances')

    bank_section = finances.at_css('[data-finance-bank-accounts]')
    expect(bank_section.text).to include('Delta Bank', bank.masked_number)
    expect(bank_section.at_css('[data-finance-empty-banks]')).to be_nil
    expect(bank_section.at_css('[data-finance-banks-content]')).to be_present
    expect(bank_section.text).not_to include('Archived Bank', '123456789012', '999987654321')
    expect(bank_section.css('[data-finance-bank-account]').size).to eq(1)
    expect(bank_section.at_css("a[href='#{admin_supplier_bank_accounts_path(supplier)}']")).to be_present
  end
end
