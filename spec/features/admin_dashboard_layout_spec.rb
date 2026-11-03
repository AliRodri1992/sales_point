# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin dashboard layout', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(user, scope: :user)
    page.driver.browser.manage.window.resize_to(1440, 1000)
    visit admin_dashboard_path
    expect(page).to have_css('#customizeDashboardButton[data-dashboard-ready="true"]:not([disabled])')
  end

  after { Warden.test_reset! }

  def start_editing
    expect(page).to have_css('#customizeDashboardButton[data-dashboard-ready="true"]:not([disabled])')
    find('#customizeDashboardButton').click
    expect(page).to have_css('#customizeDashboardButton[aria-pressed="true"]')
  end

  def resize_chart
    find('[gs-id="sales-chart"] .dashboard-layout-handle').send_keys(%i[shift arrow_left])
    expect(page).to have_css('[gs-id="sales-chart"][gs-w="7"]')
  end

  scenario 'connects real quick actions and safely returns through Turbo navigation' do
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const boxes = [...document.querySelectorAll('#mainDashboardGrid .grid-stack-item')]
          .map(item => item.getBoundingClientRect())
        return boxes.every((a, i) => boxes.every((b, j) => i === j ||
          a.right <= b.left + 1 || a.left >= b.right - 1 || a.bottom <= b.top + 1 || a.top >= b.bottom - 1))
      })()
    JS
    expect(page).to have_text('Preview with sample data.')
    expect(page).to have_no_css('.dashboard-overview a[href="#"]')
    find('.dashboard-quick-actions a[href="/admin/products/new"]').click
    expect(page).to have_current_path(new_admin_product_path)
    find('#adminSidebar a[href="/admin/dashboard"]', match: :first).click
    start_editing
    expect(page).to have_css('.dashboard-layout-handle', count: 8)
    find('#cancelDashboardButton').click
    find('.dashboard-quick-actions a[href="/admin/clients/new"]').click
    expect(page).to have_current_path(new_admin_client_path)
  end

  scenario 'restores the original layout when cancelling keyboard changes' do
    start_editing
    resize_chart
    find('#cancelDashboardButton').click
    expect(page).to have_css('[gs-id="sales-chart"][gs-w="8"]')
    expect(page).to have_css('#customizeDashboardButton[aria-pressed="false"]')
    expect(user.dashboard_preferences).to be_empty
  end

  scenario 'saves a keyboard-adjusted layout and restores it after reload' do
    start_editing
    resize_chart
    find('#customizeDashboardButton').click
    expect(page).to have_css('#customizeDashboardButton[aria-pressed="false"]')
    expect(user.dashboard_preferences.find_by!(widget_id: 'sales-chart').width).to eq(7)
    page.refresh
    expect(page).to have_css('[gs-id="sales-chart"][gs-w="7"]')
    expect(page).to have_css('.dashboard-layout-handle', count: 8, visible: :all)
  end

  scenario 'keeps unsaved changes editable when the server rejects a save' do
    start_editing
    resize_chart
    page.execute_script(<<~JS)
      const originalFetch = window.fetch
      window.fetch = (url, options) => String(url).includes('/admin/dashboard/preferences')
        ? Promise.resolve(new Response(JSON.stringify({ success: false }), {
            status: 200, headers: { 'Content-Type': 'application/json' }
          }))
        : originalFetch(url, options)
    JS
    find('#customizeDashboardButton').click
    expect(page).to have_css('.swal2-popup', text: 'Save failed')
    find('.swal2-confirm').click
    expect(page).to have_css('#customizeDashboardButton[aria-pressed="true"]:not([disabled])')
    expect(page).to have_css('[gs-id="sales-chart"][gs-w="7"]')
    find('#cancelDashboardButton').click
    expect(page).to have_css('[gs-id="sales-chart"][gs-w="8"]')
    expect(user.dashboard_preferences).to be_empty
  end

  scenario 'prevents duplicate saves and editing while a save is pending' do
    start_editing
    page.execute_script(<<~JS)
      const originalFetch = window.fetch
      window.fetch = (url, options) => String(url).includes('/admin/dashboard/preferences')
        ? new Promise(resolve => { window.finishDashboardSave = () => resolve(new Response(
            JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } }
          )) })
        : originalFetch(url, options)
    JS
    find('#customizeDashboardButton').click
    expect(page).to have_css('#customizeDashboardButton[disabled][aria-busy="true"]')
    expect(page).to have_button('Cancel', disabled: true)
    page.execute_script('window.finishDashboardSave()')
    expect(page).to have_css('#customizeDashboardButton[aria-pressed="false"]:not([disabled])')
  end

  scenario 'keeps cards within mobile and tablet screens and disables layout editing' do
    [320, 390, 768, 1024].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      expect(page).to have_css('#mainDashboardGrid.gs-1')
      expect(page).to have_css('#kpiGrid.gs-1')
      expect(page).to have_css('#customizeDashboardButton[disabled]')
      dimensions = page.evaluate_script(<<~JS)
        [...document.querySelectorAll('.dashboard-overview, .dashboard-overview .grid-stack-item')].map(item => ({
          class: item.className, width: item.clientWidth, scroll: item.scrollWidth,
          left: item.getBoundingClientRect().left, right: item.getBoundingClientRect().right
        }))
      JS
      expect(page.evaluate_script(<<~JS)).to be(true), "Dashboard overflow at #{width}px: #{dimensions}"
        (() => {
          const overview = document.querySelector('.dashboard-overview')
          return document.documentElement.scrollWidth <= innerWidth &&
            [...overview.querySelectorAll('.grid-stack-item')].every(item => {
              const box = item.getBoundingClientRect()
              return box.left >= 0 && box.right <= innerWidth + 1
            })
        })()
      JS
      page.execute_script(
        'window.scrollTo(0, document.getElementById("kpiGrid").getBoundingClientRect().top + scrollY - 90)'
      )
    end
  end

  scenario 'discards unfinished desktop edits when switching to mobile' do
    start_editing
    resize_chart
    page.driver.browser.manage.window.resize_to(390, 900)
    expect(page).to have_css('#customizeDashboardButton[aria-pressed="false"][disabled]')
    page.driver.browser.manage.window.resize_to(1440, 1000)
    expect(page).to have_css('#customizeDashboardButton[data-dashboard-ready="true"]:not([disabled])')
    expect(page).to have_css('[gs-id="sales-chart"][gs-w="8"]')
    expect(user.dashboard_preferences).to be_empty
  end
end
