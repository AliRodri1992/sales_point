require 'rails_helper'

RSpec.describe 'Admin::Languages Diagnostic', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'inactive') }

  before do
    permission_role = create(:system_role, :system)
    create(:user_role, user:, system_role: permission_role)
    GranularPermissionCatalog.sync!
    codes = GranularPermissionCatalog::ACTIONS.map { |action| "languages.#{action}" }
    Permission.where(code: codes).find_each do |permission|
      create(:system_role_permission, system_role: permission_role, permission:)
    end
    sign_in user
  end

  it 'create response body contains swal toast' do
    post admin_languages_path(format: :turbo_stream),
         params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'inactive' } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('action="swal"')
  end

  it 'create stores user param' do
    post admin_languages_path(format: :turbo_stream),
         params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'inactive' } }

    notification = Noticed::Notification.last

    expect(notification.params[:action]).to eq('created')
    expect(notification.params[:user]).to eq(user)
  end

  it 'destroy response body contains swal toast' do
    language = create(:language, name: 'ToDelete', code: 'td', flag_iso: 'td')
    delete admin_language_path(language, format: :turbo_stream)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('action="swal"')
  end

  it 'destroy stores user param' do
    language = create(:language, name: 'ToDelete', code: 'td', flag_iso: 'td')
    delete admin_language_path(language, format: :turbo_stream)

    notification = Noticed::Notification.last

    expect(notification.params[:action]).to eq('destroyed')
    expect(notification.params[:user]).to eq(user)
  end
end
