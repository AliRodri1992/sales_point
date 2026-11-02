# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::SessionsController, type: :request do
  let(:password) { 'password123' }
  let!(:user) { create(:user, password:) }
  let!(:english_language) { create(:language, :english) }

  it 'renders the sign-in form and stores terminal defaults' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.cookies['terminal_language']).to eq('en')
    expect(response.cookies['terminal_theme']).to eq('theme-material-red')

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[data-controller="language-selector"] button svg')).to be_present
    expect(document.at_css('[data-terminal-target="themeDropdown"]')).to be_present
    expect(document.css('svg')).not_to be_empty
  end

  it 'renders validation errors when credentials are incomplete' do
    post user_session_path, params: { user: { email: '', password: '' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(flash[:alert]).to be_nil
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('#user_email')['class']).to include('input-field-error')
    expect(page.at_css('#user_password')['class']).to include('input-field-error')
    expect(page.text).not_to include('Password confirmation')
    expect(page.at_css('form[action="/users/sign_in"]')).to be_present
    expect(page.at_css('[data-controller="swal-flash"]')).to be_nil
    expect(page.at_css('[data-controller="swal-flash"] form')).to be_nil
  end

  it 'shows model-derived field messages below their inputs, without browser-native validation' do
    post user_session_path, params: { user: { email: '', password: '' } }

    document = Nokogiri::HTML(response.body)
    form = document.at_css('form[action="/users/sign_in"]')
    locale = document.at_css('html')['lang']
    expect(form['novalidate']).to be_present
    expect(document.at_css('#login-email-error').text).to include(User.human_attribute_name(:email, locale:))
    expect(document.at_css('#login-password-error').text).to include(User.human_attribute_name(:password, locale:))
    expect(document.at_css('#user_email')['data-auth-blank-message'])
      .to include(User.human_attribute_name(:email, locale:))
  end

  it 'keeps the remember-me selection when credentials are incomplete' do
    post user_session_path, params: { user: { email: '', password: '', remember_me: '1' } }

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('#user_remember_me')['checked']).to be_present
  end

  it 'exposes accessible password and theme controls' do
    get new_user_session_path

    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-action*="terminal#togglePassword"]')['aria-pressed']).to eq('false')
    expect(page.at_css('[data-theme-toggle]')['aria-expanded']).to eq('false')
    expect(page.at_css('#user_email')['required']).to be_present
    expect(page.at_css('#user_password')['required']).to be_present
  end

  it 'renders a standalone flash alert outside the authentication form' do
    post user_session_path, params: { user: { email: '', password: '' } }

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[data-controller="swal-flash"]')).to be_nil
    expect(document.at_css('[data-controller="swal-flash"] form')).to be_nil
    expect(document.at_css('form[action="/users/sign_in"]')).to be_present
  end

  it 'exposes accessible field validation and localized password controls' do
    post user_session_path, params: { user: { email: '', password: '' } }

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#user_email')['aria-invalid']).to eq('true')
    expect(document.at_css('#user_password')['aria-invalid']).to eq('true')
    expect(document.at_css('#login-email-error [data-server-field-error]')).to be_present
    locale = document.at_css('html')['lang']
    expect(document.at_css('[data-show-label]')['data-show-label'])
      .to eq(I18n.t('authentication.login.show_password', locale:))
  end

  it 'rejects suspended and blocked accounts even when the password is correct' do
    %w[suspended blocked].each do |status|
      user.update!(status:)
      post user_session_path, params: { user: { email: user.email, password: } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(session['warden.user.user.key']).to be_nil
    end
  end

  it 'signs out an existing session when an administrator blocks the account' do
    sign_in user
    user.update!(status: 'blocked')

    get admin_dashboard_path

    expect(response).to redirect_to(new_user_session_path)
    expect(controller.current_user).to be_nil
  end

  it 'signs in successfully and stores the SweetAlert session message' do
    post user_session_path, params: {
      user: { email: user.email, password: }
    }

    expect(response).to redirect_to(admin_dashboard_path)
    expect(session[:swal_icon]).to eq('success')
    expect(session[:swal_message]).to eq(I18n.t('devise.sessions.signed_in'))
  end

  context 'with an eight-character password' do
    let(:password) { '12345678' }

    it 'rejects even correct credentials before creating a session' do
      post user_session_path, params: { user: { email: user.email, password: } }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      field = document.at_css('#user_password')
      locale = document.at_css('html')['lang']
      message = I18n.t('activerecord.errors.models.user.attributes.password.login_too_short', locale:, count: 9)
      expect(field['aria-invalid']).to eq('true')
      expect(field['aria-describedby']).to eq('login-password-error')
      expect(document.at_css('#login-password-error').text).to include(message)
      expect(session['warden.user.user.key']).to be_nil

      get admin_dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'with a nine-character password' do
    let(:password) { '123456789' }

    it 'accepts the exact minimum length when credentials are correct' do
      post user_session_path, params: { user: { email: user.email, password: } }

      expect(response).to redirect_to(admin_dashboard_path)
    end
  end

  it 'rejects malformed email before authentication and associates its error with the field' do
    post user_session_path, params: { user: { email: 'invalid-address', password: 'not-a-real-password' } }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#user_email')['aria-describedby']).to eq('login-email-error')
    locale = document.at_css('html')['lang']
    message = I18n.t('activerecord.errors.models.user.attributes.email.invalid', locale:)
    expect(document.at_css('#login-email-error').text).to include(message)
    expect(document.at_css('#user_email')['value']).to eq('invalid-address')
  end

  it 'shows the same generic rejection for unknown accounts and incorrect passwords' do
    [user.email, 'absent@example.invalid'].each do |email|
      post user_session_path, params: { user: { email:, password: 'not-a-real-password' } }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      alert = document.at_css('[data-login-rejected][data-controller="swal-flash"]')
      expect(alert['data-swal-flash-message-value']).to eq(I18n.t('authentication.login.invalid_credentials'))
      expect(alert['data-swal-flash-icon-value']).to eq('error')
      expect(alert['data-swal-flash-mode-value']).to eq('toast')
      expect(alert['data-swal-flash-persistent-value']).to eq('true')
      expect(document.at_css('#login-feedback').text).to be_blank
      expect(document.at_css('#user_email')['value']).to eq(email)
      expect(document.at_css('#user_password')['value']).to be_blank
      expect(controller.current_user).to be_nil
    end
  end

  it 'keeps the chosen language on a rejected sign-in' do
    spanish = create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    cookies[:terminal_language] = spanish.code

    post user_session_path, params: { user: { email: 'absent@example.invalid', password: 'incorrect' } }

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('html')['lang']).to eq('es')
    alert = document.at_css('[data-login-rejected]')
    expect(alert['data-swal-flash-message-value'])
      .to eq(I18n.t('authentication.login.invalid_credentials', locale: :es))
    expect(alert['data-swal-flash-close-label-value'])
      .to eq(I18n.t('authentication.login.close_error', locale: :es))
    expect(document.at_css('#languageSelectorButton').text).to include('ES')
  end

  it 'displays the sign-in success via SweetAlert2 once on the dashboard' do
    post user_session_path, params: { user: { email: user.email, password: } }
    follow_redirect!

    page = Nokogiri::HTML(response.body)
    alert = page.at_css('#flash [data-controller="swal-flash"]')
    expect(alert['data-swal-flash-message-value']).to eq(I18n.t('devise.sessions.signed_in'))
    expect(alert['data-swal-flash-icon-value']).to eq('success')
    expect(alert['data-swal-flash-mode-value']).to eq('toast')
    expect(session[:swal_message]).to be_nil

    get admin_dashboard_path
    expect(Nokogiri::HTML(response.body).at_css('#flash [data-controller="swal-flash"]')).to be_nil
  end

  it 'shows already authenticated as a SweetAlert2 toast, not a flash banner' do
    sign_in user
    get new_user_session_path
    expect(response).to redirect_to(admin_dashboard_path)
    follow_redirect!

    page = Nokogiri::HTML(response.body)
    alert = page.at_css('#flash [data-controller="swal-flash"]')
    expect(alert['data-swal-flash-message-value']).to eq(I18n.t('devise.failure.already_authenticated'))
    expect(alert['data-swal-flash-icon-value']).to eq('info')
    expect(alert['data-swal-flash-mode-value']).to eq('toast')
    expect(page.at_css('#flash .bg-rose-50')).to be_nil
    expect(page.at_css('#flash .bg-emerald-50')).to be_nil
    expect(session[:swal_mode]).to be_nil

    get admin_dashboard_path
    expect(Nokogiri::HTML(response.body).at_css('#flash [data-controller="swal-flash"]')).to be_nil
  end
end
