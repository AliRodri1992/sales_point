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

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  def account(name:, clabe:)
    SupplierBankAccount.create!(
      supplier:, organization:, bank_name: name, holder_name: 'Supplier Vendor',
      clabe:, currency_code: 'MXN'
    )
  end

  scenario 'clears the visible bank selection when a payment switches suppliers' do
    other_supplier = create(:supplier, organization:)
    bank = account(name: 'Original Bank', clabe: '032180000118359719')
    SupplierBankAccount.create!(
      supplier: other_supplier, organization:, bank_name: 'New Bank',
      holder_name: 'Other Vendor', clabe: '012180001234567899',
      currency_code: supplier.currency.code
    )
    bank.update!(currency_code: supplier.currency.code)

    visit new_admin_supplier_payment_path

    page.execute_script(<<~JS)
      const form = document.querySelector('[data-controller="supplier-payment-bank"]')
      const supplier = form.querySelector('[name="supplier_payment[supplier_id]"]')
      const currency = form.querySelector('[name="supplier_payment[currency_id]"]')
      supplier.value = '#{supplier.id}'
      supplier.dispatchEvent(new Event('change', { bubbles: true }))
      currency.value = '#{supplier.currency.id}'
      currency.dispatchEvent(new Event('change', { bubbles: true }))
      const bank = form.querySelector('[name="supplier_payment[supplier_bank_account_id]"]')
      bank.value = '#{bank.id}'
      bank.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    selected = find('select[name="supplier_payment[supplier_bank_account_id]"]', visible: :all)
    bank_picker = selected.find(:xpath, '..').find('button[aria-haspopup="listbox"]')
    expect(selected.value).to eq(bank.id.to_s)
    expect(bank_picker.text).to include('Original Bank')

    page.execute_script(<<~JS)
      const supplier = document.querySelector('[name="supplier_payment[supplier_id]"]')
      supplier.value = '#{other_supplier.id}'
      supplier.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    expect(selected.value).to be_blank
    expect(bank_picker.text).not_to include('Original Bank')
    expect(bank_picker['aria-expanded']).to eq('false')
  end

  scenario 'shows blocked bank accounts distinctly from active and verified accounts' do
    blocked = account(name: 'Blocked Bank', clabe: '032180000118359719')
    verified = account(name: 'Verified Bank', clabe: '012180001234567899')
    blocked.update!(status: 'blocked', blocked_reason: 'Review required')
    verified.update!(verification_status: 'verified')
    visit admin_supplier_bank_accounts_path(supplier)

    expect(page).to have_css('[data-bank-operational-status="blocked"]', count: 1)
    expect(page).to have_css('[data-bank-verification-status="verified"]', count: 1)
    expect(page).to have_css('[data-bank-operational-status="active"]', count: 1)
  end

  scenario 'offers to clear restrictive filters after a bank search has no results' do
    account(name: 'Existing Bank', clabe: '032180000118359719')
    visit admin_supplier_bank_accounts_path(supplier, q: 'No Match')
    expect(page).to have_css('[data-bank-accounts-empty]', visible: true)
    expect(page).to have_link(href: admin_supplier_bank_accounts_path(supplier))
  end

  scenario 'filters bank accounts without exposing the encrypted CLABE' do
    account(name: 'First Bank', clabe: '032180000118359719')
    account(name: 'Other Bank', clabe: '012180001234567899')
    visit admin_supplier_bank_accounts_path(supplier)

    expect(page).to have_css('[data-supplier-bank-accounts-target="card"]', count: 2)
    expect(page).to have_no_text('032180000118359719')
    fill_in 'q', with: 'First Bank'
    click_button 'Search'

    expect(page).to have_css('[data-supplier-bank-accounts-target="card"]', count: 1)
    expect(page).to have_text('First Bank')
    expect(page).to have_no_css('[data-supplier-bank-accounts-target="card"]', text: 'Other Bank')
  end

  scenario 'displays the approved bank cards within View Supplier and keeps search in that tab' do
    account(name: 'BBVA México', clabe: '032180000118359719')
    visit admin_supplier_path(supplier, tab: 'bank_accounts')

    expect(page).to have_css('#supplier-dossier-bank-accounts:not(.hidden)', visible: true)
    expect(page).to have_css('#supplier-dossier-bank-accounts [data-supplier-bank-accounts-target="card"]', count: 1)
    expect(page).to have_css(
      '#supplier-dossier-bank-accounts [data-finance-banks-search-row] ' \
      "a[href='#{admin_supplier_bank_accounts_path(supplier)}']", visible: true
    )

    within('#supplier-dossier-bank-accounts') do
      expect(page).to have_text('BBVA')
      expect(page).to have_no_text('032180000118359719')
      expect(page).to have_no_text('MXN')
      find('#dossier-banks-search').fill_in with: 'BBVA'
      find('summary', text: 'All banks').click
      find('button[role="option"][data-option-value="BBVA México"]').click
      click_button 'Search'
    end

    expect(page).to have_current_path(/banks_q=BBVA/)
    expect(page).to have_current_path(admin_supplier_path(supplier), ignore_query: true)
    expect(URI.decode_www_form(URI.parse(page.current_url).query).to_h).to include(
      'tab' => 'bank_accounts', 'banks_q' => 'BBVA', 'banks_bank' => 'BBVA México'
    )
    expect(page).to have_css('#supplier-dossier-bank-accounts:not(.hidden)', visible: true)
    expect(page).to have_css('#supplier-dossier-bank-accounts [data-supplier-bank-accounts-target="card"]', count: 1)
  end

  scenario 'moves keyboard focus from bank accounts to the financial statement' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit admin_supplier_path(supplier, tab: 'bank_accounts')

    bank_tab = find('[role="tab"][data-section="bank_accounts"]')
    expect(bank_tab['aria-controls']).to eq('supplier-dossier-bank-accounts')
    expect(bank_tab['aria-selected']).to eq('true')

    bank_tab.send_keys(:arrow_down)
    expect(page).to have_css('[role="tab"][data-section="statement"][aria-selected="true"]')
    expect(page).to have_css('#supplier-dossier-statement:not(.hidden)', visible: true)
  end

  scenario 'does not offer new financial accounts when a supplier is inactive' do
    account(name: 'History Bank', clabe: '032180000118359719')
    supplier.update!(status: :inactive)
    visit admin_supplier_bank_accounts_path(supplier)

    expect(page).to have_text('History Bank')
    expect(page).to have_no_css("a[href='#{new_admin_supplier_bank_account_path(supplier)}']")
    expect(page).to have_no_text('032180000118359719')
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
