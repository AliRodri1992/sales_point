# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authenticated landing actions', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:user) { create(:user, :english, username: 'Landing User') }

  before do
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after do
    Warden.test_reset!
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  scenario 'opens the existing profile through a keyboard-accessible account menu' do
    visit root_path
    expect(page).to have_no_link('Sign in')
    expect(page).to have_no_link('Start')
    expect(page).to have_link('Go to dashboard', href: admin_dashboard_path)
    account = find('[data-navbar-target="accountMenu"]', visible: true)
    account.find('summary').send_keys(:enter)
    expect(account).to have_link(I18n.t('admin.shared.user_menu.my_profile'))
    account.find('summary').send_keys(:escape)
    expect(page).to have_no_css('[data-navbar-target="accountMenu"][open]')
    expect(account).to have_css('summary:focus')
    account.find('summary').click
    find('h1').click
    expect(page).to have_no_css('[data-navbar-target="accountMenu"][open]')
    account.find('summary').click
    within(account) { click_link I18n.t('admin.shared.user_menu.my_profile') }
    expect(page).to have_current_path(admin_profile_path)
    expect(page).to have_field('Username', with: user.username)
  end

  scenario 'offers dashboard and logout on mobile and restores visitor actions after logout' do
    page.driver.browser.manage.window.resize_to(320, 740)
    visit '/home/index'
    page.driver.browser.manage.add_cookie(name: 'terminal_language', value: 'en')
    find('[data-navbar-target="button"]').click
    within '#landing-mobile-menu' do
      expect(page).to have_link('Go to dashboard', href: admin_dashboard_path)
      find('[data-navbar-target="accountMenu"] summary').click
      click_button I18n.t('admin.shared.user_menu.sign_out')
    end
    expect(page).to have_current_path(root_path)
    expect(page).to have_link(I18n.t('landing.buttons.start'), href: new_user_registration_path)
    expect(page).to have_no_css('[data-navbar-target="accountMenu"]')
    expect(page).to have_no_link(I18n.t('landing.buttons.dashboard'))
    page.go_back
    expect(page).to have_current_path('/home/index')
    expect(page).to have_no_css('[data-navbar-target="accountMenu"]')
    expect(page).to have_link(I18n.t('landing.buttons.start'), href: new_user_registration_path)
  end

  scenario 'keeps a long user name and the account menu inside narrow and desktop viewports' do
    user.update!(username: 'Usuario de prueba con un nombre de cuenta muy largo')
    visit root_path
    [320, 768, 1280, 1440].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      find('[data-navbar-target="button"]').click if width < 1280
      account = find('[data-navbar-target="accountMenu"]', visible: true)
      account.find('summary').click
      expect(page.evaluate_script(<<~JS)).to be(true), "Overflow at #{width}px"
        (() => {
          const menu = [...document.querySelectorAll('[data-navbar-target="accountMenu"]')]
            .find(element => element.getBoundingClientRect().width > 0)
          const popup = menu.querySelector('summary + div').getBoundingClientRect()
          return popup.left >= 0 && popup.right <= innerWidth &&
            document.documentElement.scrollWidth <= innerWidth
        })()
      JS
      account.find('summary').send_keys(:escape)
      find('[data-navbar-target="button"]').click if width < 1280
    end
  end
end
