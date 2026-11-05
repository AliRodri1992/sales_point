# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile validation and supported languages', type: :request do
  let(:user) { create(:user) }

  it 'preserves the account email and re-renders errors after an invalid edit' do
    sign_in user
    original_email = user.email
    patch admin_profile_path, params: { profile: { email: 'invalid-address' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.email).to eq(original_email)
    expect(response.body).to include('invalid-address')
  end

  it 'renders an available locale when the user selects a language without translations' do
    user.update!(language: create(:language, code: 'zz', name: 'Custom language'))
    sign_in user
    get admin_profile_path
    expect(response).to have_http_status(:ok)
    expect(%w[en es ko]).to include(Nokogiri::HTML(response.body).at_css('html')['lang'])
  end

  it 'ignores unsupported terminal language cookies on the sign-in page' do
    cookies[:terminal_language] = 'unknown-language'
    get new_user_session_path
    expect(response).to have_http_status(:ok)
    expect(%w[en es ko]).to include(Nokogiri::HTML(response.body).at_css('html')['lang'])
  end
end
