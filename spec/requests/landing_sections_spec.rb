require 'rails_helper'

RSpec.describe 'Landing section management', type: :request do
  let(:user) { create(:user, user_type: :delta) }

  before do
    create(:landing_section, key: 'hero', position: 1, enabled: true)
    create(:landing_section, key: 'faq', position: 2, enabled: false)
    sign_in user
  end

  describe 'GET /landing_sections' do
    it 'allows an authorized Delta administrator to access the screen' do
      get landing_sections_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('landing-sections')
    end
  end

  describe 'PATCH /landing_sections/:id/toggle' do
    it 'toggles the section visibility' do
      section = LandingSection.find_by!(key: 'hero')

      patch landing_section_toggle_path(section)

      expect(section.reload.enabled).to be(false)
      expect(response).to redirect_to(landing_sections_path)
    end
  end

  context 'when the user is not a Delta administrator' do
    let(:user) { create(:user, user_type: :employee) }

    it 'returns forbidden' do
      get landing_sections_path

      expect(response).to have_http_status(:forbidden)
    end
  end
end
