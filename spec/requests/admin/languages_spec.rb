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

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('language_selector', target: 'language_selector_content', html: kind_of(String))

      post admin_languages_path(format: :turbo_stream),
           params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'active' } }
    end

    it 'defaults the status to active when not provided' do
      expect do
        post admin_languages_path(format: :turbo_stream),
             params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl' } }
      end.to change(Language, :count).by(1)

      expect(Language.find_by(code: 'tl').status).to eq('active')
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

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('language_selector', target: 'language_selector_content', html: kind_of(String))

      patch admin_language_path(language, format: :turbo_stream),
            params: { language: { name: 'New Name', code: 'ol', flag_iso: 'ol', status: 'active' } }
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

    it 'stores the actor user in the notification params' do
      delete admin_language_path(language, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.params[:user]).to eq(user)
    end

    it 'keeps the soft-deleted language record accessible on the notification' do
      delete admin_language_path(language, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.record).to be_a(Language)
      expect(notification.record.code).to eq('td')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with('language_selector', target: 'language_selector_content', html: kind_of(String))

      delete admin_language_path(language, format: :turbo_stream)
    end

    it 'appears in user.notifications even when the language is soft-deleted' do
      delete admin_language_path(language, format: :turbo_stream)

      notification = user.notifications.find_by(
        noticed_events: { record_type: 'Language', record_id: language.id }
      )
      expect(notification).to be_present
      expect(notification.params[:action]).to eq('destroyed')
    end
  end

  describe 'GET /admin/languages' do
    before do
      create_list(:language, 15)
    end

    it 'returns a paginated list with at least 10 items per page' do
      get admin_languages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.languages.index.total_count', count: Language.not_deleted.count))
    end

    it 'respects the per_page query param' do
      get admin_languages_path(per_page: 5)

      expect(response).to have_http_status(:ok)
    end

    it 'shows the total count of languages (not just page count)' do
      get admin_languages_path

      total = Language.not_deleted.count
      expect(response.body).to include(I18n.t('admin.languages.index.total_count', count: total))
    end

    it 'sorts by name in descending order when direction=desc' do
      get admin_languages_path(sort: 'name', direction: 'desc')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by code column' do
      get admin_languages_path(sort: 'code')

      expect(response).to have_http_status(:ok)
    end

    it 'filters by search term' do
      create(:language, name: 'Spanish', code: 'es', flag_iso: 'es')

      get admin_languages_path(search: 'Spanis')

      expect(response).to have_http_status(:ok)
    end

    it 'filters by status' do
      create(:language, status: 'inactive')

      get admin_languages_path(status: 'inactive')

      expect(response).to have_http_status(:ok)
    end
  end
end
