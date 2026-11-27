# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Advanced product filter design', type: :feature, js: true do
  include Warden::Test::Helpers

  before do
    organization = create(:organization)
    user = create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user:)
    create(:product, organization:, name: 'Filter tea', price: 25)
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'keeps actions after the fields and controls usable at every breakpoint' do
    [1440, 768, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 1000)
      visit admin_products_path
      summary = find('.products-filters__advanced > summary')
      summary.send_keys(:enter)
      expect(page).to have_css('.products-filters__advanced[open]')
      expect(page).to have_css('.products-v9-filter-grid button.products-v9-filter-submit', text: 'Search')
      expect(page.evaluate_script(<<~JS)).to be(true)
        (() => {
          const panel = document.querySelector('.products-filter-panel')
          const grid = panel.querySelector('.products-v9-filter-grid')
          const apply = grid.querySelector('.products-v9-filter-submit').getBoundingClientRect()
          const controls = [...grid.querySelectorAll('.products-filters__field input, .products-filters__field select, .products-filters__advanced > summary, .products-v9-filter-submit')]
            .filter(node => node.getClientRects().length).map(node => node.getBoundingClientRect())
          const fields = [...grid.querySelectorAll('.products-filters__group')].map(node => node.getBoundingClientRect())
          return controls.every(box => box.height >= 40 && box.left >= 0 && box.right <= innerWidth) &&
            apply.top < Math.min(...fields.map(box => box.top)) &&
            document.documentElement.scrollWidth <= innerWidth
        })()
      JS
    end
  end

  scenario 'updates the advanced count during live search and retains the applied criteria after reload' do
    visit admin_products_path
    find('.products-filters__advanced > summary').click
    fill_in 'products_min_price', with: '5'
    fill_in 'products_search', with: 'Filter tea'

    expect(page).to have_current_path(/min_price=5/)
    expect(page).to have_css('.products-filters__advanced-count', text: '1', exact_text: true)
    expect(page).to have_field('products_min_price', with: '5')
    page.refresh
    expect(page).to have_css('.products-filters__advanced[open]')
    expect(page).to have_field('products_min_price', with: '5')
    expect(page).to have_css('#admin_products_list', text: 'Filter tea')
  end
end
