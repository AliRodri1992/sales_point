# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Scoped skeleton loading', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'preserves existing table data while the region refreshes' do
    create(:supplier, organization:, name: 'Visible Supplier')
    visit admin_suppliers_path

    expect(page).to have_text('Visible Supplier')
    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('skeleton:begin', {
        detail: { region: 'suppliers', requestId: 11 }
      }))
    JS

    expect(page).to have_css('[data-skeleton-loading-region-value="suppliers"][aria-busy="true"]')
    expect(page).to have_text('Visible Supplier')
    expect(page).to have_css('[data-skeleton-loading-target="placeholder"][hidden]', visible: :all)

    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('skeleton:end', {
        detail: { region: 'suppliers', requestId: 11 }
      }))
    JS
    expect(page).to have_css('[data-skeleton-loading-region-value="suppliers"][aria-busy="false"]')
  end

  scenario 'shows placeholders for an empty region and ignores stale responses' do
    visit admin_suppliers_path

    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('skeleton:begin', {
        detail: { region: 'suppliers', requestId: 21 }
      }))
      document.dispatchEvent(new CustomEvent('skeleton:begin', {
        detail: { region: 'suppliers', requestId: 22 }
      }))
      document.dispatchEvent(new CustomEvent('skeleton:end', {
        detail: { region: 'suppliers', requestId: 21 }
      }))
    JS

    expect(page).to have_css('[data-skeleton-loading-region-value="suppliers"][aria-busy="true"]')
    expect(page).to have_css('[data-skeleton-loading-target="placeholder"]:not([hidden])', wait: 5)
    expect(page).to have_css('.delta-skeleton--table', visible: true)

    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('skeleton:end', {
        detail: { region: 'suppliers', requestId: 22 }
      }))
    JS
    expect(page).to have_css('[data-skeleton-loading-region-value="suppliers"][aria-busy="false"]')
    expect(page).to have_css('[data-skeleton-loading-target="placeholder"][hidden]', visible: :all)
  end

  scenario 'provides card-shaped placeholders in supplier contact and address tabs' do
    supplier = create(:supplier, organization:)
    visit admin_supplier_path(supplier, tab: 'contacts')

    expect(page).to have_css('[data-supplier-contacts-target="skeleton"][aria-hidden="true"]', visible: :all)
    expect(page).to have_css('[data-supplier-addresses-target="skeleton"][aria-hidden="true"]', visible: :all)
    expect(page).to have_css('[data-supplier-documents-target="skeleton"][aria-hidden="true"]', visible: :all)
    expect(page).to have_css('.delta-skeleton--card', minimum: 2, visible: :all)
  end

  scenario 'targets product searches to their own Turbo Frame' do
    visit admin_products_path

    expect(page).to have_css('form[data-turbo-frame="admin_products_list"]')
    expect(page).to have_css('[data-skeleton-loading-region-value="admin_products_list"]')
    expect(page).to have_css('[data-skeleton-loading-region-value="admin_products_list"][aria-busy="false"]')
  end
end
