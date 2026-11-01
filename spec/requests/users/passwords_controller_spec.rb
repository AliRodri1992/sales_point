# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::PasswordsController, type: :request do
  it 'renders the password recovery form in the authentication layout' do
    get new_user_password_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('main form[action="/users/password"]')).to be_present
    expect(document.at_css('input[type="email"][required]')).to be_present
    expect(document.at_css('a[href="/users/sign_in"]')).to be_present
  end

  it 'renders the reset form with the token and confirmation field' do
    get edit_user_password_path, params: { reset_password_token: 'sample-token' }

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('input[name="user[reset_password_token]"]')).to be_present
    expect(document.at_css('input[name="user[password_confirmation]"][required]')).to be_present
  end
end
