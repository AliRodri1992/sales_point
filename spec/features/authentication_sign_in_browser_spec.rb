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

    expect(page).to have_css('.swal2-toast.swal2-icon-error', text: I18n.t('authentication.login.invalid_credentials'))
    expect(page).to have_css('form[action="/users/sign_in"]')
    expect(page).to have_css('#user_email')
    expect(page).to have_css('#user_password')
    expect(find('[data-terminal-target="loginSubmit"]')).not_to be_disabled
    expect(find('#user_email').value).to eq('nobody@example.com')
    expect(page).to have_css('#user_password:focus')
    expect(page).to have_no_css('#login-feedback', visible: true)
    find('.swal2-close').click
    expect(page).to have_no_css('.swal2-toast')
    expect(page).to have_css('#user_password:focus')

    fill_in 'user_password', with: 'another-wrong-password'
    find('[data-terminal-target="loginSubmit"]').click
    expect(page).to have_css('.swal2-toast.swal2-icon-error', count: 1)
  end

  scenario 'blocks malformed email locally and allows correcting and retrying' do
    visit new_user_session_path
    fill_in 'user_email', with: 'invalid-address'
    fill_in 'user_password', with: 'not-a-real-password'
    find('[data-terminal-target="loginSubmit"]').click

    expect(find('#user_email')['aria-invalid']).to eq('true')
    expect(page).to have_css('#login-email-error', text: 'valid email address')
    expect(find('[data-terminal-target="loginSubmit"]')).not_to be_disabled
    fill_in 'user_email', with: 'absent@example.invalid'
    find('#user_password').send_keys(:enter)
    expect(page).to have_css('.swal2-toast.swal2-icon-error', text: I18n.t('authentication.login.invalid_credentials'))
  end

  scenario 'requires more than eight password characters even when visibility is toggled' do
    visit new_user_session_path
    fill_in 'user_email', with: 'absent@example.invalid'
    fill_in 'user_password', with: '12345678'
    find('[data-action*="terminal#togglePassword"]').click
    find('[data-terminal-target="loginSubmit"]').click

    expect(find('#user_password')['minlength']).to eq('9')
    expect(find('#user_password')['aria-invalid']).to eq('true')
    expect(page).to have_css('#login-password-error', text: 'Password must contain at least 9 characters.')
    expect(find('[data-terminal-target="loginSubmit"]')).not_to be_disabled

    fill_in 'user_password', with: '123456789'
    find('[data-terminal-target="loginSubmit"]').click
    expect(page).to have_css('.swal2-toast.swal2-icon-error', text: I18n.t('authentication.login.invalid_credentials'))
  end

  scenario 'recovers from a transport failure with a visible message' do
    visit new_user_session_path
    page.execute_script(<<~JS)
      window.fetch = () => Promise.reject(new TypeError('Test connection unavailable'));
    JS
    fill_in 'user_email', with: 'absent@example.invalid'
    fill_in 'user_password', with: 'not-a-real-password'
    find('[data-terminal-target="loginSubmit"]').click

    expect(page).to have_css('#login-feedback', text: I18n.t('authentication.login.network_error'))
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
