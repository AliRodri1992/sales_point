# frozen_string_literal: true

RSpec.describe Users::SessionsController, type: :request do
  let(:password) { 'password123' }
  let!(:user) { create(:user, password:) }

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
    expect(flash[:alert]).to eq(I18n.t('devise.failure.invalid'))
  end

  it 'signs in successfully and stores the SweetAlert session message' do
    post user_session_path, params: {
      user: { email: user.email, password: }
    }

    expect(response).to redirect_to(admin_dashboard_path)
    expect(session[:swal_icon]).to eq('success')
    expect(session[:swal_message]).to eq(I18n.t('devise.sessions.signed_in'))
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
