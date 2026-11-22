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
      expect(page).to have_css('footer.products-filters__footer button', text: 'Apply filters')
      expect(page.evaluate_script(<<~JS)).to be(true)
        (() => {
          const panel = document.querySelector('.products-filter-panel')
          const footer = panel.querySelector('.products-filters__footer').getBoundingClientRect()
          const controls = [...panel.querySelectorAll('input, button, summary, .products-filters__clear')]
            .filter(node => node.getClientRects().length).map(node => node.getBoundingClientRect())
          const fields = [...panel.querySelectorAll('.products-filters__group')].map(node => node.getBoundingClientRect())
          return controls.every(box => box.height >= 44 && box.left >= 0 && box.right <= innerWidth) &&
            footer.top >= Math.max(...fields.map(box => box.bottom)) && document.documentElement.scrollWidth <= innerWidth
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
