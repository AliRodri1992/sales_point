# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Delta POS sign-in experience', type: :feature, js: true do
  before do
    create(:language, :english)
    create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  scenario 'keeps the sign-in form usable after an invalid password' do
    visit new_user_session_path
    fill_in 'user_email', with: 'nobody@example.com'
    fill_in 'user_password', with: 'wrong-password'
    find('button[type="submit"]').click

    expect(page).to have_css('form[action="/users/sign_in"]')
    expect(page).to have_css('#user_email')
    expect(page).to have_css('#user_password')
    expect(find('[data-terminal-target="loginSubmit"]')).not_to be_disabled
  end

  scenario 'shows model-derived missing-field errors inline without native browser bubbles' do
    visit new_user_session_path

    form = find('form[action="/users/sign_in"]')
    expect(form['novalidate']).to be_present
    find('[data-terminal-target="loginSubmit"]').click

    email = find('#user_email')
    password = find('#user_password')
    expect(email['aria-invalid']).to eq('true')
    expect(password['aria-invalid']).to eq('true')
    expect(find('#login-email-error').text).to eq(email['data-auth-blank-message'])
    expect(find('#login-password-error').text).to eq(password['data-auth-blank-message'])
  end

  scenario 'toggles password visibility and restores the accessible label' do
    visit new_user_session_path
    fill_in 'user_password', with: 'not-a-secret'
    button = find('[data-action*="terminal#togglePassword"]')

    button.click
    expect(find('#user_password')[:type]).to eq('text')
    expect(button['aria-pressed']).to eq('true')
    expect(button['aria-label']).to eq(button['data-hide-label'])

    button.click
    expect(find('#user_password')[:type]).to eq('password')
    expect(button['aria-pressed']).to eq('false')
    expect(button['aria-label']).to eq(button['data-show-label'])
  end

  scenario 'opens theme and language selectors with keyboard-friendly states' do
    visit new_user_session_path
    find('[data-theme-toggle]').click
    expect(find('[data-theme-toggle]')['aria-expanded']).to eq('true')

    find('[data-theme="theme-delta-emerald"]').click
    expect(find('[data-theme="theme-delta-emerald"]', visible: :all)['aria-pressed']).to eq('true')
    expect(find('[data-theme-toggle]')['aria-expanded']).to eq('false')

    find('#languageSelectorButton').click
    expect(find('#languageSelectorButton')['aria-expanded']).to eq('true')
    find('#languageSelectorButton').send_keys(:escape)
    expect(find('#languageSelectorButton')['aria-expanded']).to eq('false')
  end

  scenario 'does not overlap the page at narrow mobile widths' do
    page.driver.browser.manage.window.resize_to(320, 740)
    visit new_user_session_path

    expect(page).to have_css('header [aria-label="Delta POS"]')
    expect(page).to have_css('#user_email')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    find("a[href='#{new_user_password_path}']").click
    expect(page).to have_css('form[action="/users/password"]')
  end
end
