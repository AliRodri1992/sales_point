# frozen_string_literal: true

RSpec.describe Users::SessionsController, type: :request do
  let(:password) { 'password123' }
  let!(:user) { create(:user, password:) }

  it 'renders the sign-in form and stores terminal defaults' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.cookies['terminal_language']).to eq('en')
    expect(response.cookies['terminal_theme']).to eq('theme-material-red')
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
end
