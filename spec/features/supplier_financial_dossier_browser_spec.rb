# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier financial dossier browser', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  def account(name:, account_number:)
    SupplierBankAccount.create!(
      supplier:, organization:, bank_name: name, holder_name: 'Supplier Vendor',
      account_number:, currency_code: 'MXN'
    )
  end

  scenario 'filters bank accounts without exposing the encrypted account number' do
    account(name: 'First Bank', account_number: '1234567890')
    account(name: 'Other Bank', account_number: '9876543210')
    visit admin_supplier_bank_accounts_path(supplier)

    expect(page).to have_css('[data-supplier-bank-accounts-target="card"]', count: 2)
    expect(page).to have_no_text('1234567890')
    fill_in 'q', with: 'First Bank'
    find('input[type="submit"]').click

    expect(page).to have_css('[data-supplier-bank-accounts-target="card"]', count: 1)
    expect(page).to have_text('First Bank')
    expect(page).to have_no_text('Other Bank')
  end

  scenario 'restores an archived account from the list without exposing secret values' do
    archived = account(name: 'Archived Bank', account_number: '1234567890')
    archived.update!(deleted_at: Time.current)
    visit admin_supplier_bank_accounts_path(supplier, archived: '1')

    expect(page).to have_text('Archived Bank')
    expect(page).to have_no_text('1234567890')
    find("form[action='#{restore_admin_supplier_bank_account_path(supplier, archived)}'] button").click

    expect(page).to have_current_path(admin_supplier_bank_accounts_path(supplier, archived: '1'), ignore_query: false)
    expect(archived.reload.deleted_at).to be_nil
  end

  scenario 'does not offer new financial accounts when a supplier is inactive' do
    account(name: 'History Bank', account_number: '1234567890')
    supplier.update!(status: :inactive)
    visit admin_supplier_bank_accounts_path(supplier)

    expect(page).to have_text('History Bank')
    expect(page).to have_no_css("a[href='#{new_admin_supplier_bank_account_path(supplier)}']")
    expect(page).to have_no_text('1234567890')
  end

  scenario 'keeps product offer price history accessible after archiving' do
    offer = SupplierProduct.create!(
      organization:, supplier:, product:, currency: supplier.currency,
      presentation_name: 'Case', units_per_package: 12, purchase_price: 120,
      minimum_quantity: 1, discount_percent: 0, freight_amount: 0,
      nonrecoverable_tax: 0, lead_time_days: 3
    )
    offer.update!(purchase_price: 150, deleted_at: Time.current, active: false)

    visit admin_supplier_supplier_products_path(supplier, archived: '1')
    expect(page).to have_text(product.name)

    visit history_admin_supplier_supplier_product_path(supplier, offer)
    expect(page).to have_text('120')
    expect(page).to have_text('150')
    expect(offer.price_history.count).to eq(2)
  end
end
