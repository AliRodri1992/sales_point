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
    expect(finances.text).to include('No pending payables', 'No active bank accounts')
    expect(finances.at_css('[data-finance-metric="invoices"]').text.strip).to eq('0')
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
    expect(bank_section.text).not_to include('Archived Bank', '123456789012', '999987654321')
    expect(bank_section.css('[data-finance-bank-account]').size).to eq(1)
    expect(bank_section.at_css("a[href='#{admin_supplier_bank_accounts_path(supplier)}']")).to be_present
  end
end
