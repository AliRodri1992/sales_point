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
