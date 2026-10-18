# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier bank accounts list', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def bank_account(attributes = {})
    SupplierBankAccount.create!({
      organization:, supplier:, bank_name: 'Example Bank',
      holder_name: 'Vendor Holdings', account_number: '123456789012',
      currency_code: 'MXN'
    }.merge(attributes))
  end

  def document
    Nokogiri::HTML(response.body)
  end

  it 'shows the reusable illustration and a registration action when no accounts exist' do
    get admin_supplier_bank_accounts_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('[data-bank-accounts-empty] img[src*="sbankaccounts"]')).to be_present
    expect(document.text).to include('No bank accounts registered yet')
    expect(document.at_css("a[href='#{new_admin_supplier_bank_account_path(supplier)}']")).to be_present
    expect(document.css('[data-supplier-bank-accounts-target="card"]')).to be_empty
  end

  it 'renders two-column account cards with masked data and permission-protected actions' do
    primary = bank_account(primary: true)
    bank_account(bank_name: 'Another Bank', holder_name: 'Vendor Finance',
                 account_number: '9876543210', currency_code: 'USD')

    get admin_supplier_bank_accounts_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('[data-supplier-bank-accounts-target="list"]')['class']).to include('xl:grid-cols-2')
    cards = document.css('[data-supplier-bank-accounts-target="card"]')
    expect(cards.length).to eq(2)
    expect(document.text).to include('Example Bank', 'Another Bank', 'Vendor Finance')
    expect(document.text).to include(primary.masked_number, 'Primary')
    expect(document.text).not_to include('123456789012', '9876543210')
    expect(response.body).not_to include('123456789012', '9876543210')
    expect(document.css('a[href^="/admin/suppliers/"][href*="/bank_accounts/"][href$="/edit"]').size).to eq(2)
    expect(document.css("form[action$='/bank_accounts/#{primary.id}']").size).to eq(1)
    expect(document.at_css('[data-bank-accounts-empty]')).to be_nil
  end

  it 'only renders active accounts from the requested supplier and organization' do
    bank_account
    bank_account(bank_name: 'Archived Bank', deleted_at: Time.current)
    other_supplier = create(:supplier, organization:)
    bank_account(supplier: other_supplier, bank_name: 'Other Supplier Bank')
    external = create(:supplier, organization: create(:organization))
    bank_account(supplier: external, organization: external.organization, bank_name: 'Outside Bank')

    get admin_supplier_bank_accounts_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(document.css('[data-supplier-bank-accounts-target="card"]').length).to eq(1)
    expect(document.text).not_to include('Archived Bank', 'Other Supplier Bank', 'Outside Bank')
  end

  it 'provides live search, currency filtering, and pagination controls' do
    bank_account(currency_code: 'MXN')
    bank_account(bank_name: 'USD Bank', currency_code: 'USD', account_number: '999900001234')

    get admin_supplier_bank_accounts_path(supplier)

    expect(document.at_css('input[data-action="input->supplier-bank-accounts#filter"]')).to be_present
    expect(document.at_css('select[data-action="change->supplier-bank-accounts#filter"] option[value="MXN"]'))
      .to be_present
    expect(document.at_css('select[data-action="change->supplier-bank-accounts#filter"] option[value="USD"]'))
      .to be_present
    expect(document.at_css('[data-supplier-bank-accounts-target="pagination"]')).to be_present
    expect(document.at_css('[data-supplier-bank-accounts-target="next"]')).to be_present
    expect(response.body).not_to include('999900001234')
  end

  it 'uses the existing supplier breadcrumb without adding supplier information cards' do
    get admin_supplier_bank_accounts_path(supplier)

    crumbs = document.css('nav[aria-label] ol li')
    expect(crumbs.map { |item| item.text.strip }).to eq(
      ['Home', 'Suppliers', supplier.name, 'Bank accounts']
    )
    expect(crumbs[2].at_css('a')['href']).to eq(admin_supplier_path(supplier))
    expect(crumbs.last.at_css('[aria-current="page"]')).to be_present
    expect(document.at_css('[data-bank-accounts-supplier-summary]')).to be_nil
  end
end
