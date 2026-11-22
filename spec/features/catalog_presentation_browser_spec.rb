# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Unified catalog presentation', type: :feature, js: true do
  include Warden::Test::Helpers

  before do
    organization = create(:organization)
    administrator = create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: administrator)
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
        expect(page.evaluate_script(<<~JS)).to be(true)
          (() => {
            const heading = document.querySelector('.catalog-module-heading')
            const title = heading.querySelector('h1')
            const box = title.getBoundingClientRect()
            return heading.querySelector('.catalog-eyebrow').getBoundingClientRect().bottom <= box.top &&
              box.left >= 0 && box.right <= innerWidth && title.scrollWidth <= title.clientWidth
          })()
        JS
      end
    end
  end
end
