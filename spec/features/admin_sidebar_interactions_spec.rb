# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sidebar interactions', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:user) { create(:user, :english) }

  before do
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'opens the same account menu in expanded and collapsed modes' do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit admin_dashboard_path

    find('#sidebarUserMenuButton').click
    expect(page).to have_css('#sidebarUserMenu:not(.hidden)')
    expect(page).to have_link(href: admin_profile_path)
    find('#sidebarUserMenuButton').send_keys(:escape)
    expect(page).to have_css('#sidebarUserMenu.hidden', visible: :all)

    find('#sidebarToggle').click
    expect(page).to have_css('#adminSidebar.sidebar-collapsed')
    expect(page).to have_css('#sidebarUserMenuButton .sidebar-avatar-initials', visible: true)
    expect(page).to have_css('#adminSidebar .sidebar-avatar', visible: :hidden)

    find('#sidebarUserMenuButton').click
    expect(page).to have_css('#sidebarUserMenu:not(.hidden)')
  end

  scenario 'opens and closes catalog flyouts while collapsed' do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit admin_dashboard_path

    find('#sidebarToggle').click
    find('#adminSidebar .sidebar-catalog > summary', match: :first).click
    expect(page).to have_css('#adminSidebarFlyout.is-visible')
    expect(page).to have_css('#adminSidebarFlyout a[href]', minimum: 1)

    page.send_keys(:escape)
    expect(page).to have_no_css('#adminSidebarFlyout', visible: :all)
  end

  scenario 'opens a modal drawer on mobile and restores focus on close' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_dashboard_path

    find('#sidebarToggle').click
    expect(page).to have_css('#adminSidebar.sidebar-open')
    expect(page.evaluate_script("document.getElementById('adminDashboardContent').inert")).to be(true)

    find('#sidebarCloseButton').click
    expect(page).to have_no_css('#adminSidebar.sidebar-open', visible: :all)
    expect(page.evaluate_script("document.getElementById('adminDashboardContent').inert")).to be(false)
    expect(page.evaluate_script('document.activeElement.id')).to eq('sidebarToggle')
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
