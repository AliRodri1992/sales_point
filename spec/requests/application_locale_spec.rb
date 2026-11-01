# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application locale selection', type: :request do
  include Devise::Test::IntegrationHelpers

  it 'prefers the signed-in user language over the browser cookie' do
    language = create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    user = create(:user, language:)
    sign_in user
    cookies[:terminal_language] = 'en'

    get root_path

    expect(response).to have_http_status(:ok)
    expect(I18n.locale).to eq(:es)
  end

  it 'uses a supported language from the browser cookie for a guest' do
    create(:language, code: 'ko', name: 'Korean', flag_iso: 'kr')
    cookies[:terminal_language] = 'ko'

    get root_path

    expect(response).to have_http_status(:ok)
    expect(I18n.locale).to eq(:ko)
  end

  it 'prefers the session language over a different browser cookie' do
    spanish = create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    create(:language, :english)

    patch '/language', params: { language: spanish.code }
    cookies[:terminal_language] = 'en'

    get root_path

    expect(response).to have_http_status(:ok)
    expect(I18n.locale).to eq(:es)
  end
end
