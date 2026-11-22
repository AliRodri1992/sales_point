# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Unified catalog presentation', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }

  before do
    administrator = create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: administrator)
    create(:category, organization:, name: 'Catalog category')
    create(:product, organization:, name: 'Catalog product')
    create(:unit_of_measure, organization:, name: 'Catalog unit')
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'keeps module titles during Turbo navigation and headings readable at every breakpoint' do
    visit admin_categories_path
    widths = [1440, 768, 390, 320]
    { admin_categories_path => 'Categories', admin_languages_path => 'Languages',
      admin_products_path => 'Products', admin_units_of_measure_path => 'Units of measure' }.each do |path, title|
      page.execute_script('window.Turbo.visit(arguments[0])', path)
      expect(page).to have_title("Delta POS | #{title}", exact: true)
      widths.each do |width|
        page.driver.browser.manage.window.resize_to(width, 900)
        expect(page).to have_css('.catalog-module-heading .catalog-eyebrow', text: 'CATALOGS', exact_text: true)
        expect(page).to have_css('h1.catalog-module-title', text: title, exact_text: true)
        expect(page).to have_css('.catalog-list-directory-heading h2')
        expect(page).to have_css('footer.catalog-list-pagination')
        if width == 1440
          expect(page).to have_css('.catalog-list-desktop-table')
          expect(page).to have_no_css('.catalog-list-mobile-list')
        else
          expect(page).to have_css('.catalog-list-mobile-list .catalog-list-mobile-card')
          expect(page).to have_no_css('.catalog-list-desktop-table')
        end
        expect(page.evaluate_script(<<~JS)).to be(true)
          (() => {
            const heading = document.querySelector('.catalog-module-heading')
            const title = heading.querySelector('h1')
            const box = title.getBoundingClientRect()
            const actions = [...document.querySelectorAll('.catalog-list-icon-button, .catalog-list-pagination-links a')]
              .filter(node => node.getClientRects().length).map(node => node.getBoundingClientRect())
            return heading.querySelector('.catalog-eyebrow').getBoundingClientRect().bottom <= box.top &&
              box.left >= 0 && box.right <= innerWidth && title.scrollWidth <= title.clientWidth &&
              actions.every(rect => rect.height >= 44 && rect.width >= 44 && rect.left >= 0 && rect.right <= innerWidth) &&
              document.documentElement.scrollWidth <= innerWidth
          })()
        JS
      end
    end
  end

  scenario 'keeps sorting, page navigation and page size available from the mobile cards' do
    create_list(:product, 11, organization:)
    create_list(:unit_of_measure, 11, organization:)
    create_list(:language, 11)
    page.driver.browser.manage.window.resize_to(390, 1000)

    { 'products' => 'products.name', 'languages' => 'name', 'units_of_measure' => 'name' }.each do |key, sort|
      visit "/admin/#{key}?per_page=5&direction=desc"
      find('.catalog-list-mobile-sort summary').send_keys(:enter)
      within('.catalog-list-mobile-sort') { find("a[href*='direction=asc'][href*='sort=#{sort}']").click }
      expect(page).to have_current_path(/sort=#{Regexp.escape(sort)}/)
      expect(page.current_url).to include('per_page=5', 'direction=asc')
      within('.catalog-list-pagination-links') { click_link '2', exact: true }
      expect(page).to have_current_path(/page=2/)
      expect(page.current_url).to include('per_page=5', "sort=#{sort}")
      page.refresh
      expect(page).to have_css('.catalog-list-pagination [aria-current="page"]', text: '2', exact_text: true)
      wrapper = find("##{key}_per_page", visible: :all).find(:xpath, '..')
      wrapper.find('button[aria-haspopup="listbox"]').click
      wrapper.find('[role="option"]', text: '10', exact_text: true).click
      expect(page).to have_current_path(/per_page=10/)
      expect(page).to have_css('.catalog-list-mobile-card', count: 10)
    end
  end
end
