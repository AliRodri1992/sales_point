require 'rails_helper'

RSpec.describe 'Dashboards', type: :request do
  let(:user) { create(:user, user_type: :delta) }

  before do
    sign_in user
  end

  describe 'GET /dashboard' do
    it 'returns http success for a Delta user' do
      get dashboard_path

      expect(response).to have_http_status(:success)
    end

    it 'renders the Delta dashboard' do
      get dashboard_path

      expect(response.body).to include('Delta POS')
    end
  end

  context 'when the user is not part of the Delta team' do
    let(:user) { create(:user, user_type: :employee) }

    it 'returns forbidden' do
      get dashboard_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when the user is not authenticated' do
    before { sign_out user }

    it 'redirects to the sign-in page' do
      get dashboard_path

      expect(response).to have_http_status(:redirect)
    end
  end
end
