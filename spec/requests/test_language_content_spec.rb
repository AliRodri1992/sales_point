require 'rails_helper'

RSpec.describe 'Language selector content endpoint', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }
  let!(:english) { create(:language, :english) }
  let!(:spanish) { create(:language, code: 'es', name: 'Español', flag_iso: 'mx', status: 'active') }

  before do
    sign_in user
  end

  it 'returns the dropdown content HTML with language buttons' do
    get '/admin/languages/content'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('language_selector_content')
    expect(response.body).to include('language-selector#select')
    expect(response.body).to include('data-language="en"')
    expect(response.body).to include('data-language="es"')
  end
end
