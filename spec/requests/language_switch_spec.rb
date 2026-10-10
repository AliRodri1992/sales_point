# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Language switch', type: :request do
  include Devise::Test::IntegrationHelpers

  describe 'PATCH /language' do
    it 'stores the selected language for a guest in the session and cookie' do
      language = create(:language, :english)

      patch '/language', params: { language: language.code }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
      expect(response.cookies['terminal_language']).to eq(language.code)
    end

    it 'persists the selected language on the signed-in user' do
      language = create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
      user = create(:user, language: nil)
      sign_in user

      patch '/language', params: { language: language.code }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
      expect(user.reload.language).to eq(language)
      expect(response.cookies['terminal_language']).to eq('es')
    end

    it 'rejects a language that is not available' do
      language = create(:language, code: 'zz', name: 'Inactive Language', flag_iso: 'zz', status: :inactive)

      patch '/language', params: { language: language.code }

      expect(response).to have_http_status(:not_found)
      expect(response.cookies['terminal_language']).to be_nil
    end
  end
end
