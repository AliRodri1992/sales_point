# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sidebar', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'PATCH /admin/sidebar' do
    it 'collapses the sidebar when the parameter is true' do
      patch admin_sidebar_path, params: { sidebar_collapsed: 'true' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.sidebar_collapsed).to be(true)
    end

    it 'expands the sidebar when the parameter is false' do
      user.update!(sidebar_collapsed: true)

      patch admin_sidebar_path, params: { sidebar_collapsed: 'false' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.sidebar_collapsed).to be(false)
    end

    it 'requires authentication' do
      sign_out user

      patch admin_sidebar_path, params: { sidebar_collapsed: 'true' }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
