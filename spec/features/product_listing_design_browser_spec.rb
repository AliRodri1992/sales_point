# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Product listing information design', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }

  before do
    user = create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user:)
    create(:product, organization:, name: 'Compact specialty coffee with a long descriptive name',
                     code: 'COFFEE-2026-01', sku: 'SKU-COFFEE-2026-01', featured: true)
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'keeps identifiers together, essential data visible and five columns readable at every width' do
    [1440, 768, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 1000)
      visit admin_products_path
      listing = width == 1440 ? '.products-directory tbody tr' : '.products-directory .catalog-list-mobile-card'
      within(listing) do
        expect(page).to have_css('.products-list-identity', text: 'COFFEE-2026-01')
        expect(page).to have_css('.products-list-identifier--sku', text: 'SKU-COFFEE-2026-01')
        expect(page).to have_css('.products-list-featured', visible: true)
        expect(page).to have_css('a.catalog-list-name-link')
      end
      expect(page.evaluate_script(<<~JS)).to be(true)
        (() => {
          const directory = document.querySelector('.products-directory')
          const table = directory.querySelector('.catalog-list-desktop-table')
          const identity = [...directory.querySelectorAll('.products-list-identity')]
            .find(node => node.getClientRects().length).getBoundingClientRect()
          return directory.querySelectorAll('thead th').length === 5 &&
            (!table.clientWidth || table.scrollWidth <= table.clientWidth) &&
            identity.left >= 0 && identity.right <= innerWidth &&
            document.documentElement.scrollWidth <= innerWidth
        })()
      JS
    end
  end

  scenario 'toggles header arrows with keyboard while retaining filters and resetting the page' do
    create_list(:product, 10, organization:, name: 'Compact coffee', price: 20)
    create(:product, organization:, name: 'Compact low price', price: 5)
    create(:product, organization:, name: 'Compact high price', price: 90)
    page.driver.browser.manage.window.resize_to(1440, 1000)
    visit admin_products_path(search: 'Compact', status: 'active', per_page: 5, page: 2)

    expect(page).to have_no_css('.products-directory .catalog-list-mobile-sort')
    find('.products-directory thead th:nth-child(2) a').send_keys(:enter)
    expect(page).to have_current_path(/sort=products.price/)
    expect(page.current_url).to include('search=Compact', 'status=active', 'per_page=5', 'direction=asc')
    expect(page).to have_no_current_path(/page=2/)
    expect(page).to have_css('th:nth-child(2)[aria-sort="ascending"]')
    expect(page).to have_css('.products-directory tbody tr:first-child', text: 'Compact low price')

    find('.products-directory thead th:nth-child(2) a').send_keys(:enter)
    expect(page).to have_current_path(/direction=desc/)
    expect(page).to have_css('th:nth-child(2)[aria-sort="descending"]')
    expect(page).to have_css('.products-directory tbody tr:first-child', text: 'Compact high price')
    find('.products-directory thead th:first-child a').send_keys(:enter)
    expect(page).to have_current_path(/sort=products.name/)
    expect(page).to have_css('th:first-child[aria-sort="ascending"]')
    expect(page).to have_css('th:nth-child(2)[aria-sort="none"]')
  end
end
