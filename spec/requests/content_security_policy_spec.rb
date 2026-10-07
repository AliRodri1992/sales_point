require 'rails_helper'

RSpec.describe 'Content Security Policy', type: :request do
  describe 'GET /up' do
    it 'serves a single Rails CSP without external image hosts' do
      get rails_health_check_path

      expect(response).to have_http_status(:ok)

      csp = response.headers.fetch('Content-Security-Policy')

      expect(csp).to eq(
        "default-src 'self'; font-src 'self' data:; img-src 'self' data:; "         "script-src 'self' https:; style-src 'self' 'unsafe-inline'; object-src 'none'"
      )
      expect(response.headers['Content-Security-Policy-Report-Only']).to be_nil
    end
  end
end
