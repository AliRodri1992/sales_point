# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Languages', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }

  before do
    sign_in user
  end

  after do
    sign_out user
  end

  describe 'POST /admin/languages' do
    it 'sends a "created" notification to the current user' do
      expect do
        post admin_languages_path(format: :turbo_stream),
             params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('created')
    end
  end

  describe 'PATCH /admin/languages/:id' do
    let!(:language) { create(:language, name: 'Old Name', code: 'ol', flag_iso: 'ol') }

    it 'sends an "updated" notification to the current user' do
      expect do
        patch admin_language_path(language, format: :turbo_stream),
              params: { language: { name: 'New Name', code: 'ol', flag_iso: 'ol', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('updated')
    end
  end

  describe 'DELETE /admin/languages/:id' do
    let!(:language) { create(:language, name: 'ToDelete', code: 'td', flag_iso: 'td') }

    it 'sends a "destroyed" notification to the current user' do
      expect do
        delete admin_language_path(language, format: :turbo_stream)
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('destroyed')
    end
  end
end
