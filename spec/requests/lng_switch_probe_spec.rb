require 'rails_helper'

RSpec.describe 'LngSwitchProbe', type: :request do
  before do
    %w[es en ko].each do |code|
      Language.find_or_create_by(code:) do |language|
        language.name = code.upcase
        language.flag_iso = code == 'es' ? 'es' : 'us'
        language.status = 'active'
      end
    end
  end

  it 'switches the browser locale' do
    get '/home/index'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('>ES<')

    patch '/language', params: { language: 'en' }.to_json,
                       headers: { 'Content-Type' => 'application/json' }

    # Language switch may return :ok (200) or :redirect (3xx) depending on implementation
    expect([200, 301, 302, 303, 307, 308]).to include(response.status)

    get '/home/index'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('>EN<')
  end
end
