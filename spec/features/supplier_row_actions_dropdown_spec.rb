# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier row actions dropdown', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    create_list(:supplier, 5, organization:)
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  def open_last_row_menu
    visit admin_suppliers_path(per_page: 5)

    trigger = find('tbody tr:last-child details[data-supplier-floating-menu="true"] > summary')
    trigger.click
    expect(page).to have_css('body > [data-supplier-floating-panel]', visible: true)
    trigger
  end

  def expect_floating_panel_visible
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const menu = document.querySelector('body > [data-supplier-floating-panel]')
        if (!menu) return false
        const rect = menu.getBoundingClientRect()
        return rect.width >= 176 &&
               rect.height > 0 &&
               rect.left >= 0 && rect.top >= 0 &&
               rect.right <= window.innerWidth &&
               rect.bottom <= window.innerHeight
      })()
    JS
  end

  scenario 'shows last-row actions outside the clipped table on compact screens' do
    page.driver.browser.manage.window.resize_to(880, 530)

    trigger = open_last_row_menu
    expect_floating_panel_visible
    expect(page).to have_css('body > [data-supplier-floating-panel] form button', visible: true)
    expect(trigger['aria-expanded']).to eq('true')

    trigger.send_keys(:escape)
    expect(page).to have_no_css('body > [data-supplier-floating-panel]', visible: :all)
    expect(page).to have_css('details[data-supplier-floating-menu="true"] [data-supplier-floating-panel]',
                             visible: :all)
    expect(trigger['aria-expanded']).to eq('false')
    expect(page.evaluate_script('document.activeElement === arguments[0]', trigger)).to be(true)
  end

  scenario 'opens and closes the action menu repeatedly without leaving a panel on body' do
    page.driver.browser.manage.window.resize_to(1400, 900)

    trigger = open_last_row_menu
    expect_floating_panel_visible

    trigger.click
    expect(page).to have_no_css('body > [data-supplier-floating-panel]', visible: :all)

    trigger.click
    expect_floating_panel_visible
    find('h1', match: :first).click
    expect(page).to have_no_css('body > [data-supplier-floating-panel]', visible: :all)
  end
end
