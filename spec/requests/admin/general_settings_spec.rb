require 'rails_helper'

RSpec.describe 'Admin general settings', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:settings) { create(:organization_setting, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    role = SystemRole.find_by(code: 'administrator') || create(:system_role, :system, code: 'administrator')
    create(:user_role, user:, system_role: role)
    settings
    sign_in user
  end

  it 'shows the organization default page-size preference' do
    get admin_general_settings_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('select[name="organization_setting[default_table_page_size]"]')).to be_present
    expect(document.at_css('option[value="10"][selected]')).to be_present
  end

  it 'updates the default without overwriting user-specific overrides' do
    preference = create(:table_page_preference, user:, organization:, per_page: 5)
    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }

    expect(response).to redirect_to(admin_general_settings_path)
    expect(settings.reload.default_table_page_size).to eq(25)
    expect(preference.reload.per_page).to eq(5)
  end

  it 'rejects invalid default sizes' do
    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 99 } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(settings.reload.default_table_page_size).to eq(10)
  end

  it 'renders individual model errors with accessible field references' do
    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 99 } }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    select = document.at_css('select[name="organization_setting[default_table_page_size]"]')
    expect(select['aria-invalid']).to eq('true')
    expect(select['aria-required']).to eq('true')
    expect(select['required']).to be_nil
    expect(select['aria-describedby']).to include('organization_setting_default_table_page_size_error')
    expect(document.at_css('#organization_setting_default_table_page_size_error').text).to include(
      'Default records per page'
    )
    expect(document.at_css('label[for="organization_setting_default_table_page_size"]').text).to include('*')
    expect(document.at_css('form').text).not_to include('Review the following fields')
  end

  it 'uses the dedicated model context without blocking on unrelated legacy settings' do
    settings.base_currency.update!(active: false)

    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }

    expect(response).to redirect_to(admin_general_settings_path)
    expect(settings.reload.default_table_page_size).to eq(25)
  end

  it 'records an immutable audit event for each changed value, never for invalid or unchanged submissions' do
    expect do
      patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }
    end.to change(GeneralSettingAuditEvent, :count).by(1)

    event = GeneralSettingAuditEvent.last
    expect(event).to have_attributes(organization:, actor: user, previous_page_size: 10, new_page_size: 25)

    expect do
      patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }
      patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 99 } }
    end.not_to change(GeneralSettingAuditEvent, :count)
  end

  it 'returns a model error with conflict status instead of overwriting a newer preference' do
    settings.update!(default_table_page_size: 25)

    patch admin_general_settings_path,
          params: { organization_setting: { default_table_page_size: 50 }, expected_default_table_page_size: 10 }

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include('changed in another session')
    expect(settings.reload.default_table_page_size).to eq(25)
    expect(GeneralSettingAuditEvent.count).to eq(0)
  end

  it 'routes an organization without initial settings to setup without restoring archived records' do
    settings.really_destroy!

    get admin_general_settings_path
    expect(response).to redirect_to(admin_onboarding_path)

    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }
    expect(response).to redirect_to(admin_onboarding_path)
  end

  it 'updates only the selected organization even when another id is submitted' do
    other = create(:organization)
    other_settings = create(:organization_setting, organization: other, default_table_page_size: 50)
    create(:organization_membership, user:, organization: other)

    patch admin_select_organization_path(other)
    patch admin_general_settings_path,
          params: { organization_setting: { default_table_page_size: 15 }, organization_id: organization.id }

    expect(response).to redirect_to(admin_general_settings_path)
    expect(other_settings.reload.default_table_page_size).to eq(15)
    expect(settings.reload.default_table_page_size).to eq(10)
    expect(GeneralSettingAuditEvent.last.organization).to eq(other)
  end

  it 'rejects changes to organizations without membership' do
    foreign = create(:organization)
    foreign_settings = create(:organization_setting, organization: foreign)
    patch admin_select_organization_path(foreign)

    expect(response).to have_http_status(:not_found)
    sign_in user
    patch admin_general_settings_path,
          params: { organization_setting: { default_table_page_size: 50 }, organization_id: foreign.id }

    expect(response).to redirect_to(admin_general_settings_path)
    expect(foreign_settings.reload.default_table_page_size).to eq(10)
  end

  it 'localizes the general settings breadcrumb in all supported languages' do
    { es: 'Configuración general', en: 'General settings', ko: '일반 설정' }.each do |locale, label|
      I18n.with_locale(locale) do
        expect(I18n.t('admin.breadcrumbs.controllers.general_settings')).to eq(label)
      end
    end
  end

  it 'returns not found when the organization settings have been archived' do
    settings.update!(deleted_at: Time.current)

    get admin_general_settings_path
    expect(response).to have_http_status(:not_found)

    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }
    expect(response).to have_http_status(:not_found)
  end

  it 'denies a system administrator without an active organization membership' do
    user.organization_memberships.find_each { |membership| membership.update!(status: :inactive) }

    get admin_general_settings_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'prevents non-administrators from reading or changing general settings' do
    user.user_roles.delete_all
    get admin_general_settings_path
    expect(response).to have_http_status(:forbidden)

    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }
    expect(response).to have_http_status(:forbidden)
    expect(settings.reload.default_table_page_size).to eq(10)
    expect(GeneralSettingAuditEvent.count).to eq(0)
  end
end
