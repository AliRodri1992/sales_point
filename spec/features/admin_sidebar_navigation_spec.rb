# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sidebar responsive navigation', type: :feature, js: true do
  include Warden::Test::Helpers
  include SidebarBrowserExpectations

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(user, scope: :user)
    page.driver.browser.manage.window.resize_to(1440, 900)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'opens the mobile drawer as an accessible dialog and restores focus on close' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_dashboard_path
    expect(page).to have_css('#sidebarToggle[data-sidebar-ready="true"]')
    find('#sidebarToggle').click

    expect(page).to have_css('#adminSidebar.sidebar-open')
    expect(find('#adminSidebar')['aria-modal']).to eq('true')
    expect(find('#adminSidebar')['aria-labelledby']).to eq('adminSidebarNavigationLabel')
    expect(find('#adminSidebar')['aria-label']).to eq('Sidebar navigation')
    expect(find('#adminSidebarNavigationLabel', visible: :all).text(:all)).to eq('Sidebar navigation')
    expect(find('#sidebarToggle', visible: :all)['aria-expanded']).to eq('true')
    expect(page).to have_css('body.sidebar-drawer-open')
    expect(find('#sidebarCloseButton')).to be_visible
    expect(page.evaluate_script('document.activeElement.id')).to eq('sidebarCloseButton')

    find('#sidebarCloseButton').click

    expect(page).not_to have_css('#adminSidebar.sidebar-open')
    expect(find('#sidebarToggle')['aria-expanded']).to eq('false')
    expect(page).not_to have_css('body.sidebar-drawer-open')
    expect(page.evaluate_script('document.activeElement.id')).to eq('sidebarToggle')
  end

  scenario 'closes the mobile sidebar with Escape and restores background interaction' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_dashboard_path
    expect(page).to have_css('#sidebarToggle[data-sidebar-ready="true"]')
    find('#sidebarToggle').click
    find('#sidebarCloseButton').send_keys(:escape)

    expect(page).not_to have_css('#adminSidebar.sidebar-open')
    expect(page).not_to have_css('[inert]')
    expect(find('#sidebarToggle')['aria-expanded']).to eq('false')
  end

  def horizontal_center(selector)
    page.evaluate_script(<<~JS, selector)
      (function(query) {
        const bounds = document.querySelector(query).getBoundingClientRect()
        return bounds.left + bounds.width / 2
      })(arguments[0])
    JS
  end

  scenario 'centers logo, navigation, disabled entries, settings and avatar on one axis' do
    user.update!(sidebar_collapsed: true)
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit admin_dashboard_path

    expect(find('#sidebarToggle')['aria-expanded']).to eq('false')
    axis = horizontal_center('#adminSidebar')
    [
      '.sidebar-brand-mark',
      "nav a[href='/admin/dashboard'] svg",
      'nav .sidebar-disabled-option svg',
      'nav svg[data-sidebar-icon="accounts-payable"]',
      'nav .sidebar-catalog > summary svg:first-child',
      '#sidebarUserMenuButton'
    ].each do |selector|
      expect(horizontal_center("#adminSidebar #{selector}")).to be_within(1).of(axis)
    end

    expect(page).to have_css('#sidebarUserMenuButton .sidebar-avatar-initials', visible: true)
    expect(page).to have_no_css('#adminSidebar .sidebar-avatar', visible: true)
    icon = find('#adminSidebar nav svg[data-sidebar-icon="suppliers"]')
    icon.hover
    expect(horizontal_center('#adminSidebar nav svg[data-sidebar-icon="suppliers"]')).to be_within(1).of(axis)
  end

  scenario 'keeps focus inside the mobile drawer and restores the main content on close' do
    page.driver.browser.manage.window.resize_to(375, 812)
    visit admin_dashboard_path
    expect(page).to have_css('#sidebarToggle[data-sidebar-ready="true"]')
    find('#sidebarToggle').click

    expect(page.evaluate_script("document.getElementById('adminDashboardContent').hasAttribute('inert')")).to be(true)
    expect(page.evaluate_script("document.getElementById('sidebarOverlay').hasAttribute('inert')")).to be(false)

    find('#sidebarCloseButton').click
    Selenium::WebDriver::Wait.new(timeout: 3, interval: 0.05).until do
      page.evaluate_script("!document.getElementById('adminDashboardContent').inert")
    end
    Selenium::WebDriver::Wait.new(timeout: 3, interval: 0.05).until do
      page.evaluate_script('document.activeElement.id') == 'sidebarToggle'
    end

    page.driver.browser.manage.window.resize_to(1440, 900)
    expect_sidebar_desktop_ready
  end

  scenario 'does not shift the selected navigation item when hovering' do
    user.update!(sidebar_collapsed: true)
    visit admin_dashboard_path

    link = find('#adminSidebar a[aria-current="page"]', match: :first)
    start_x = horizontal_center('#adminSidebar a[aria-current="page"] svg')
    link.hover
    expect(horizontal_center('#adminSidebar a[aria-current="page"] svg')).to be_within(1).of(start_x)
  end

  scenario 'opens the collapsed catalog with keyboard and restores focus after Escape' do
    user.update!(sidebar_collapsed: true)
    visit admin_dashboard_path

    summary = find('#adminSidebar .sidebar-catalog > summary', match: :first)
    summary.send_keys(:enter)
    expect(page).to have_css('#adminSidebarFlyout.is-visible')
    find('#adminSidebarFlyout a[href]', match: :first).send_keys(:escape)
    expect(page).to have_no_css('#adminSidebarFlyout')
    expect(page.evaluate_script('document.activeElement.tagName')).to eq('SUMMARY')
    expect(page).to have_no_css('#adminSidebarFlyout', wait: 1)
  end

  scenario 'keeps the sidebar drawer within the viewport across mobile and tablet sizes' do
    [320, 375, 390, 768].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      visit admin_dashboard_path
      find('#sidebarToggle').click

      Selenium::WebDriver::Wait.new(timeout: 3, interval: 0.05).until do
        page.evaluate_script("Math.abs(document.getElementById('adminSidebar').getBoundingClientRect().left) < 1")
      end
      bounds = page.evaluate_script(<<~JS)
        (function() {
          const rect = document.getElementById('adminSidebar').getBoundingClientRect()
          return { left: rect.left, right: rect.right, viewport: window.innerWidth }
        })()
      JS
      expect(bounds['left']).to be_within(1).of(0)
      expect(bounds['right']).to be <= bounds['viewport']
      find('#sidebarCloseButton').click
    end
  end

  scenario 'shows unavailable administrative functions inside the collapsed settings flyout' do
    user.update!(sidebar_collapsed: true)
    visit admin_dashboard_path
    expect(page).to have_css('#sidebarToggle[data-sidebar-ready="true"]')

    summaries = all('#adminSidebar .sidebar-catalog > summary', visible: :all)
    summaries.last.send_keys(:enter)
    expect(page).to have_css('#adminSidebarFlyout.is-visible')
    expect(page).to have_css('#adminSidebarFlyout [aria-disabled="true"]', minimum: 1)
  end

  scenario 'does not attach a second toggle listener after repeated Turbo visits' do
    user.update!(sidebar_collapsed: false)
    visit admin_dashboard_path
    visit admin_suppliers_path
    visit admin_dashboard_path
    expect(page).to have_css('#sidebarToggle[data-sidebar-ready="true"]')
    find('#sidebarToggle').click

    expect_sidebar_collapsed
    expect(page).to have_css('#sidebarToggle[data-sidebar-save-state="saved"]')
    expect(user.reload.sidebar_collapsed).to be(true)
  end

  scenario 'keeps the account menu usable on a collapsed desktop sidebar' do
    user.update!(sidebar_collapsed: true)
    visit admin_dashboard_path

    expect_sidebar_collapsed
    find('#sidebarUserMenuButton').click
    expect(page).to have_css('#sidebarUserMenu:not(.hidden)')
    expect(page).to have_link('My profile')
    expect(page).to have_button('Sign out')
  end
end
