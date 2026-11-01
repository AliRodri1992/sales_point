# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier responsive dossier navigation', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
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

  scenario 'selects and clears supplier filters without radio controls' do
    create(:supplier, organization:, name: 'Active Filter Supplier', status: :active)
    create(:supplier, organization:, name: 'Inactive Filter Supplier', status: :inactive)
    visit admin_suppliers_path

    find('[data-advanced-filters] > summary').click
    status = find('[data-advanced-filters] details[data-controller="supplier-dropdown"]', match: :first)
    expect(status).to have_no_css('input[type="radio"]', visible: :all)

    status.find('summary').click
    status.find('button[role="option"][data-option-value="inactive"]').click

    expect(status.find('input[name="status"]', visible: :all).value).to eq('inactive')
    expect(status).to have_css('button[data-option-value="inactive"][aria-selected="true"]', visible: :all)
    expect(page).to have_current_path(/status=inactive/)
    expect(page).to have_text('Inactive Filter Supplier')

    find('#supplier_active_filters a[data-filter-key="status"]').click

    expect(status).to have_css('button[data-option-value="all"][aria-selected="true"]', visible: :all)
    expect(status.find('input[name="status"]', visible: :all).value).to eq('all')
    expect(page).to have_no_css('details[data-controller="supplier-dropdown"] input[type="radio"]', visible: :all)
  end

  scenario 'automatically updates the list when selecting records per page' do
    create_list(:supplier, 26, organization:)
    visit admin_suppliers_path

    selector = find('#supplier-pagination-form [data-controller="delta-select"]')
    selector.find('button[aria-haspopup="listbox"]').click
    selector.find('[role="option"]', text: '25').click

    expect(page).to have_current_path(/per_page=25/)
    expect(page).to have_css('tbody tr', count: 25)
    expect(page).to have_no_css('#supplier-pagination-form button[type="submit"]')
  end

  scenario 'keeps direct supplier actions accessible without a clipped floating menu' do
    supplier
    visit admin_suppliers_path

    actions = find('tbody tr:first-child td:last-child > div')
    actions.scroll_to(:center)
    expect(actions).to have_css('a[aria-label]', minimum: 2)
    expect(actions).to have_css('form button[aria-label]', minimum: 1)
    expect(actions).to have_no_css('details[data-supplier-floating-menu]', visible: :all)
  end

  scenario 'labels the supplier catalog search for screen-reader users' do
    visit admin_suppliers_path
    expect(page).to have_css('label[for="search"]')
    expect(page).to have_css('input#search[type="search"]')
  end

  scenario 'keeps the active section accessible on a narrow screen' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_supplier_path(supplier, tab: 'addresses')

    expect(page).to have_css('[data-section="addresses"][data-supplier-dossier-target="panel"]:not(.hidden)')
    mobile = find('[data-supplier-dossier-target="mobileSelect"]', visible: :all)
    expect(mobile.value).to eq('addresses')

    page.execute_script(<<~JS)
      const select = document.querySelector('[data-supplier-dossier-target="mobileSelect"]')
      select.value = 'contacts'
      select.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    expect(page).to have_css('[data-section="contacts"][data-supplier-dossier-target="panel"]:not(.hidden)')
    expect(page).to have_current_path(/tab=contacts/)
  end

  scenario 'explains filtered contact empty states without offering an unrelated create action' do
    visit admin_supplier_path(supplier, tab: 'contacts')
    find('[data-supplier-contacts-target="search"]').fill_in with: 'nonexistent contact name'
    expect(page).to have_css('[data-supplier-contacts-target="empty"]', visible: true)
    expect(page).to have_text('No contacts match your filters')
    expect(page).to have_no_css('[data-supplier-contacts-target="emptyAction"]', visible: true)
    expect(find('[data-supplier-contacts-target="emptyText"]', visible: true)['aria-live']).to eq('polite')
  end

  scenario 'updates the custom mobile section label when browser history changes tabs' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_supplier_path(supplier, tab: 'contacts')

    picker = find('select[data-supplier-dossier-target="mobileSelect"]', visible: :all)
    label = picker.find(:xpath, '..').find('button[aria-haspopup="listbox"]')
    expect(label.text).to include(I18n.t('admin.supplier_dossier.sections.contacts', locale: :en))

    page.execute_script(<<~JS)
      const picker = document.querySelector('select[data-supplier-dossier-target="mobileSelect"]')
      picker.value = 'addresses'
      picker.dispatchEvent(new Event('change', { bubbles: true }))
    JS
    expect(picker.value).to eq('addresses')
    page.go_back

    expect(picker.value).to eq('contacts')
    expect(label.text).to include(I18n.t('admin.supplier_dossier.sections.contacts', locale: :en))
  end

  scenario 'keeps finance navigation and panels connected at tablet width' do
    page.driver.browser.manage.window.resize_to(820, 1180)
    visit admin_supplier_path(supplier, tab: 'bank_accounts')

    expect(page).to have_css('[data-controller="delta-select"] button[aria-haspopup="listbox"]', visible: true)
    mobile = find('select[data-supplier-dossier-target="mobileSelect"]', visible: :all)
    expect(mobile.value).to eq('bank_accounts')
    expect(page).to have_css('#supplier-dossier-bank-accounts:not(.hidden)', visible: true)
    expect(page).to have_css(
      'button[data-section="bank_accounts"][aria-controls="supplier-dossier-bank-accounts"]',
      visible: :all
    )
  end

  scenario 'highlights the entire selected section without a left accent border' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit admin_supplier_path(supplier, tab: 'contacts')
    tab = find('[role="tab"][data-section="contacts"]')
    expect(tab['class']).to include('bg-emerald-50')
    expect(tab['class']).not_to include('border-l-[3px]')
  end

  scenario 'supports vertical keyboard navigation between authorized sections' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit admin_supplier_path(supplier, tab: 'general')

    current = find('[role="tab"][data-section="general"]')
    current.send_keys(:arrow_down)
    expect(page).to have_css('[role="tab"][data-section="fiscal"][aria-selected="true"]')
    expect(page).to have_css('[role="tabpanel"][data-section="fiscal"]:not(.hidden)')
    expect(page).to have_current_path(/tab=fiscal/)
  end

  scenario 'marks only the visible desktop section as current and supports browser history' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit admin_supplier_path(supplier)

    find('[data-supplier-dossier-target="tab"][data-section="documents"]').click
    expect(page).to have_css('[data-supplier-dossier-target="tab"][data-section="documents"][aria-selected="true"]')
    expect(page).to have_css('[data-section="documents"][data-supplier-dossier-target="panel"]:not(.hidden)')

    find('[data-supplier-dossier-target="tab"][data-section="contacts"]').click
    expect(page).to have_css('[data-section="contacts"][data-supplier-dossier-target="panel"]:not(.hidden)')
    page.go_back
    expect(page).to have_css('[data-section="documents"][data-supplier-dossier-target="panel"]:not(.hidden)')
  end
end
