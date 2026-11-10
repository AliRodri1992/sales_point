# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Languages', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }

  before do
    create(:organization_membership, user:)
    role = create(:system_role, :system)
    create(:user_role, user:, system_role: role)
    GranularPermissionCatalog.sync!
    codes = GranularPermissionCatalog::ACTIONS.map { |action| "languages.#{action}" }
    Permission.where(code: codes).find_each do |permission|
      create(:system_role_permission, system_role: role, permission:)
    end
    sign_in user
  end

  after do
    sign_out user
  end

  describe 'modal create/edit contracts' do
    let(:frame_headers) { { 'Turbo-Frame' => 'language_modal' } }

    it 'renders new and edit forms within the existing dialog frame' do
      language = create(:language, name: 'French draft', code: 'fr', flag_iso: 'fr', status: 'inactive')

      get new_admin_language_path, headers: frame_headers
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('turbo-frame#language_modal [role="dialog"]')).to be_present
      expect(document.at_css('form[data-turbo-frame="language_modal"]')).to be_present
      expect(document.at_css('[data-modal-dismiss]')).to be_present

      get edit_admin_language_path(language), headers: frame_headers
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('turbo-frame#language_modal [role="dialog"]')).to be_present
      expect(document.at_css('#language_code[readonly]')).to be_present
    end

    it 'preserves validation messages in the frame on an invalid create' do
      post admin_languages_path, headers: frame_headers.merge('Accept' => 'text/vnd.turbo-stream.html'),
                                 params: { language: { name: '', code: '', flag_iso: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('turbo-frame#language_modal [role="dialog"]')).to be_present
      expect(document.at_css('#language_name_error')).to be_present
    end

    it 'keeps an invalid edit inside the dialog' do
      language = create(:language, name: 'French draft', code: 'fr', flag_iso: 'fr', status: 'inactive')

      patch admin_language_path(language),
            headers: frame_headers.merge('Accept' => 'text/vnd.turbo-stream.html'),
            params: { language: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('turbo-frame id="language_modal"')
      expect(language.reload.name).to eq('French draft')
    end

    it 'closes the modal through a successful Turbo Stream response' do
      post admin_languages_path,
           headers: frame_headers.merge('Accept' => 'text/vnd.turbo-stream.html'),
           params: { language: { name: 'French draft', code: 'fr', flag_iso: 'fr', status: 'inactive' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target="language_modal"')
      expect(response.body).to include('target="languages_list"')
      expect(Language.find_by(code: 'fr')).to be_present
    end
  end

  describe 'GET /admin/languages/new' do
    it 'renders the new language form' do
      get new_admin_language_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="language[name]"')
    end
  end

  describe 'GET /admin/languages/:id' do
    it 'renders an existing language' do
      language = create(:language, name: 'Language details', code: 'ld', flag_iso: 'ld')

      get admin_language_path(language)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Language details')
    end
  end

  describe 'POST /admin/languages' do
    it 'sends a "created" notification to the current user' do
      expect do
        post admin_languages_path(format: :turbo_stream),
             params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'inactive' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('created')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .at_least(:once)
        .with('language_selector', target: 'language_selector_content', html: kind_of(String))

      post admin_languages_path(format: :turbo_stream),
           params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'inactive' } }
    end

    it 'defaults the status to active when not provided' do
      expect do
        post admin_languages_path(format: :turbo_stream),
             params: { language: { name: 'Español', code: 'es', flag_iso: 'mx' } }
      end.to change(Language, :count).by(1)

      expect(Language.find_by(code: 'es').status).to eq('active')
    end

    it 're-renders the form when the language is invalid' do
      post admin_languages_path,
           params: { language: { name: '', code: '', flag_iso: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'redirects after an HTML create and sets a notice' do
      post admin_languages_path,
           params: { language: { name: 'HTML Language', code: 'hl', flag_iso: 'hl', status: 'inactive' } }

      expect(response).to redirect_to(admin_languages_path)
      expect(flash[:notice]).to eq(I18n.t('admin.languages.created'))
    end
  end

  describe 'unsupported and protected language changes' do
    it 'rejects activation of a language absent from the configured locales' do
      post admin_languages_path,
           params: { language: { name: 'Français', code: 'fr', flag_iso: 'fr', status: 'active' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Language.find_by(code: 'fr')).to be_nil
    end

    it 'rejects a code change from a forged request' do
      language = create(:language, :english)
      patch admin_language_path(language),
            params: { language: { code: 'ko' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(language.reload.code).to eq('en')
    end

    it 'does not allow removing the default Spanish language' do
      language = create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
      delete admin_language_path(language)

      expect(response).to have_http_status(:see_other)
      expect(language.reload.deleted_at).to be_nil
    end
  end

  describe 'PATCH /admin/languages/:id' do
    let!(:language) { create(:language, name: 'Old Name', code: 'ol', flag_iso: 'ol') }

    it 'sends an "updated" notification to the current user' do
      expect do
        patch admin_language_path(language, format: :turbo_stream),
              params: { language: { name: 'New Name', code: 'ol', flag_iso: 'ol', status: 'inactive' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('updated')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .at_least(:once)
        .with('language_selector', target: 'language_selector_content', html: kind_of(String))

      patch admin_language_path(language, format: :turbo_stream),
            params: { language: { name: 'New Name', code: 'ol', flag_iso: 'ol', status: 'inactive' } }
    end

    it 're-renders the edit form when the update is invalid' do
      patch admin_language_path(language),
            params: { language: { name: '', code: 'ol', flag_iso: 'ol' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'redirects after an HTML update and sets a notice' do
      patch admin_language_path(language),
            params: { language: { name: 'Updated HTML Language', code: 'ol', flag_iso: 'ol', status: 'inactive' } }

      expect(response).to redirect_to(admin_languages_path)
      expect(flash[:notice]).to eq(I18n.t('admin.languages.updated'))
    end
  end

  describe 'catalog authorization' do
    it 'forbids language actions for an authenticated user without catalog permission' do
      restricted = create(:user, status: 'active')
      create(:organization_membership, user: restricted)
      sign_out user
      sign_in restricted

      get admin_languages_path
      expect(response).to have_http_status(:forbidden)

      post admin_languages_path,
           params: { language: { name: 'Unauthorized', code: 'zz', flag_iso: 'zz', status: 'inactive' } }
      expect(response).to have_http_status(:forbidden)
      expect(Language.find_by(code: 'zz')).to be_nil
    end
  end

  describe 'DELETE /admin/languages/:id' do
    let!(:language) { create(:language, name: 'ToDelete', code: 'td', flag_iso: 'td') }

    it 'retains search, status and sorting when a filtered language is deleted' do
      language.update!(status: 'inactive')
      create(:language, name: 'Another language', code: 'ot', flag_iso: 'ot', status: 'inactive')

      delete admin_language_path(language, search: 'ToDelete', status: 'inactive', sort: 'code',
                                           direction: 'desc', per_page: 5, format: :turbo_stream)

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css('.languages-active-filters')).to be_present
      expect(page.at_css('.languages-empty')).to be_present
      expect(page.at_css('.languages-name')).to be_nil
      expect(response.body).to include('sort=code')
      expect(language.reload.deleted_at).to be_present
    end

    it 'clamps the page after deleting the sole record on the last page' do
      language.update!(status: 'inactive')
      create_list(:language, [6 - Language.not_deleted.count, 0].max, status: 'inactive')

      delete admin_language_path(language, per_page: 5, page: 2, format: :turbo_stream)

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.css('.languages-desktop-table tbody tr').size).to eq(5)
      expect(page.at_css('.languages-page-size')).to be_nil
    end

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
        .at_least(:once)
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

    it 'uses full navigation for sorting and pagination to synchronize filter controls' do
      get admin_languages_path(search: 'Language', status: 'inactive', per_page: 5, sort: 'name')

      document = Nokogiri::HTML(response.body)
      sort_link = document.at_css('.languages-desktop-table th:nth-child(2) a')
      page_link = document.at_css('.languages-pagination-links a')

      expect(sort_link['data-turbo-frame']).to eq('_top')
      expect(sort_link['href']).to include('search=Language')
      expect(sort_link['href']).to include('status=inactive')
      expect(page_link['data-turbo-frame']).to eq('_top') if page_link
    end

    it 'hides page-size controls for a catalog that cannot fill the smallest page' do
      Language.not_deleted.find_each do |language|
        language.update!(deleted_at: Time.current) unless language.code == I18n.default_locale.to_s
      end

      get admin_languages_path

      page = Nokogiri::HTML(response.body)
      expect(page.at_css('.languages-page-size')).to be_nil
      expect(page.at_css('.languages-pagination-links')).to be_nil
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

    it 'keeps the page subtitle and New language on the same row above filters' do
      get admin_languages_path

      document = Nokogiri::HTML(response.body)
      row = document.at_css('.languages-page-header .languages-description-row')
      action = row.at_css('.languages-new-button')
      filters = document.at_css('section.languages-filters')

      expect(row.at_css('p').text.strip).to eq(I18n.t('admin.languages.index.subtitle'))
      expect(action['data-turbo-frame']).to eq('language_modal')
      expect(filters).to be_present
      expect(document.at_css('.languages-actions-bar')).to be_nil
      expect(document.at_css('.languages-filters .languages-new-button')).to be_nil
      expect(document.css('.languages-new-button').size).to eq(1)
      expect(document.at_css('header.languages-page-header + section.languages-filters')).to eq(filters)
    end

    it 'renders compact automatic filters without a wide submit input' do
      get admin_languages_path

      form = Nokogiri::HTML(response.body).at_css('form.languages-filter-form')
      expect(form).to be_present
      expect(form['data-controller']).to eq('languages-search')
      expect(form.at_css('input[type="submit"]')).to be_nil
      expect(form.at_css('input#search')['data-action']).to include('debouncedSubmit')
      expect(form.at_css('select#status')['data-action']).to include('submitNow')
    end

    it 'differentiates filtered empty results from an empty catalog' do
      get admin_languages_path(search: 'nothing-matches-this-language')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.languages.ui.no_results_title'))
      expect(response.body).to include('languages-active-filters')
      expect(response.body).not_to include(I18n.t('admin.languages.index.empty_title'))
    end

    it 'keeps filter parameters in removable chips' do
      get admin_languages_path(search: 'Language', status: 'inactive', sort: 'name')

      page = Nokogiri::HTML(response.body)
      chips = page.css('.languages-filter-chip')
      expect(chips.size).to eq(2)
      expect(chips[0]['href']).to include('status=inactive')
      expect(chips[1]['href']).to include('search=Language')
    end

    it 'filters by status' do
      create(:language, status: 'inactive')

      get admin_languages_path(status: 'inactive')

      expect(response).to have_http_status(:ok)
    end
  end
end
