# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sidebar responsive navigation', type: :feature, js: true do
  include Warden::Test::Helpers

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

  scenario 'opens the mobile drawer as an accessible dialog and restores focus on close' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_dashboard_path
    find('#sidebarToggle').click

    expect(page).to have_css('#adminSidebar.sidebar-open')
    expect(find('#adminSidebar')['aria-modal']).to eq('true')
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
    find('#sidebarToggle').click
    find('#sidebarCloseButton').send_keys(:escape)

    expect(page).not_to have_css('#adminSidebar.sidebar-open')
    expect(page).not_to have_css('[inert]')
    expect(find('#sidebarToggle')['aria-expanded']).to eq('false')
  end

  scenario 'keeps the account menu usable on a collapsed desktop sidebar' do
    user.update!(sidebar_collapsed: true)
    visit admin_dashboard_path

    expect(page).to have_css('#adminSidebar.sidebar-collapsed')
    find('#sidebarUserMenuButton').click
    expect(page).to have_css('#sidebarUserMenu:not(.hidden)')
    expect(page).to have_link('My profile')
    expect(page).to have_button('Sign out')
  end
end
