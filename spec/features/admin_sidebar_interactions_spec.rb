# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sidebar interactions', type: :feature, js: true do
  include Warden::Test::Helpers
  include SidebarBrowserExpectations

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'opens the same account menu in expanded and collapsed modes' do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit admin_dashboard_path
    expect(page).to have_css('#sidebarToggle[data-sidebar-ready="true"]')

    find('#sidebarUserMenuButton').click
    expect(page).to have_css('#sidebarUserMenu:not(.hidden)')
    expect(page).to have_link(href: admin_profile_path)
    find('#sidebarUserMenuButton').send_keys(:escape)
    expect(page).to have_css('#sidebarUserMenu.hidden', visible: :all)
    expect(page.evaluate_script('window.innerWidth')).to be >= 1024

    find('#sidebarToggle').click
    expect_sidebar_collapsed
    expect(page).to have_css('#sidebarToggle[data-sidebar-save-state="saved"]')
    expect(page).to have_css('#sidebarUserMenuButton .sidebar-avatar-initials', visible: true)
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const sidebar = document.getElementById('adminSidebar').getBoundingClientRect()
        const dashboard = document.querySelector('#adminSidebar nav a[href]').getBoundingClientRect()
        return Math.abs((sidebar.left + sidebar.width / 2) - (dashboard.left + dashboard.width / 2)) < 1
      })()
    JS
    expect(page).to have_css('#adminSidebar .sidebar-avatar', visible: :hidden)

    find('#sidebarUserMenuButton').click
    expect(page).to have_css('#sidebarUserMenu:not(.hidden)')
  end

  scenario 'opens and closes catalog flyouts while collapsed' do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit admin_dashboard_path
    expect(page).to have_css('#sidebarToggle[data-sidebar-ready="true"]')
    expect(page.evaluate_script('window.innerWidth')).to be >= 1024

    find('#sidebarToggle').click
    expect_sidebar_collapsed
    find('#adminSidebar .sidebar-catalog > summary', match: :first).click
    expect(page).to have_css('#adminSidebarFlyout.is-visible')
    expect(page).to have_css('#adminSidebarFlyout a[href]', minimum: 1)
    expect(find('#adminSidebar .sidebar-catalog > summary', match: :first)['aria-expanded']).to eq('true')

    find('body').send_keys(:escape)
    expect(page).to have_no_css('#adminSidebarFlyout', visible: :all)
    expect(page).to have_no_css('#adminSidebarFlyout', wait: 1)
  end

  scenario 'closes the mobile drawer from its overlay and restores focus' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_dashboard_path

    find('#sidebarToggle').click
    expect(page).to have_css('#adminSidebar.sidebar-open')
    find('#sidebarOverlay').click
    expect(page).to have_no_css('#adminSidebar.sidebar-open', visible: :all)
    expect(page.evaluate_script('document.activeElement.id')).to eq('sidebarToggle')
  end

  scenario 'keeps the selected dashboard link readable when keyboard focused' do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit admin_dashboard_path

    active_link = find('#adminSidebar nav a[aria-current="page"]', match: :first)
    active_link.send_keys(:tab)
    page.execute_script('arguments[0].focus()', active_link.native)

    expect(page.evaluate_script(<<~JS)).to eq('rgb(255, 255, 255)')
      getComputedStyle(document.querySelector('#adminSidebar nav a[aria-current="page"]')).color
    JS
  end

  scenario 'opens a modal drawer on mobile and restores focus on close' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_dashboard_path

    find('#sidebarToggle').click
    expect(page).to have_css('#adminSidebar.sidebar-open')
    expect(page.evaluate_script("document.getElementById('adminDashboardContent').inert")).to be(true)

    find('#sidebarCloseButton').click
    expect(page).to have_no_css('#adminSidebar.sidebar-open', visible: :all)
    Selenium::WebDriver::Wait.new(timeout: 3, interval: 0.05).until do
      page.evaluate_script("!document.getElementById('adminDashboardContent').inert")
    end
    Selenium::WebDriver::Wait.new(timeout: 3, interval: 0.05).until do
      page.evaluate_script('document.activeElement.id') == 'sidebarToggle'
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
