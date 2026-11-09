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

  def update_default(size, token: settings.reload.updated_at.utc.iso8601(6))
    patch admin_general_settings_path,
          params: { organization_setting: { default_table_page_size: size },
                    expected_settings_updated_at: token }
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
    update_default(25)

    expect(response).to redirect_to(admin_general_settings_path)
    expect(settings.reload.default_table_page_size).to eq(25)
    expect(preference.reload.per_page).to eq(5)
  end

  it 'rejects invalid default sizes' do
    update_default(99)

    expect(response).to have_http_status(:unprocessable_content)
    expect(settings.reload.default_table_page_size).to eq(10)
  end

  it 'keeps the persisted preview value after rejecting an unsupported page size' do
    update_default(99)

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    summary = document.at_css('[data-general-settings-preview-target="summary"]')
    expect(summary.text).to include('Showing 10 records per page by default.')
    expect(summary.text).not_to include('99 records')
    expect(document.at_css('[data-general-settings-preview-original-value]')[
      'data-general-settings-preview-original-value'
    ]).to eq('10')
  end

  it 'renders individual model errors with accessible field references' do
    update_default(99)

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

    update_default(25)

    expect(response).to redirect_to(admin_general_settings_path)
    expect(settings.reload.default_table_page_size).to eq(25)
  end

  it 'records an immutable audit event for each changed value, never for invalid or unchanged submissions' do
    expect do
      update_default(25)
    end.to change(GeneralSettingAuditEvent, :count).by(1)

    event = GeneralSettingAuditEvent.last
    expect(event).to have_attributes(organization:, actor: user, previous_page_size: 10, new_page_size: 25)

    expect do
      update_default(25)
      update_default(99)
    end.not_to change(GeneralSettingAuditEvent, :count)
  end

  it 'rejects a PATCH without the required revision token' do
    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }

    expect(response).to have_http_status(:conflict)
    expect(settings.reload.default_table_page_size).to eq(10)
  end

  it 'detects concurrent A-to-B-to-A updates even when the selected size is unchanged' do
    original_token = settings.updated_at.utc.iso8601(6)
    settings.update!(default_table_page_size: 25, updated_at: 1.minute.from_now)
    settings.update!(default_table_page_size: 10, updated_at: 2.minutes.from_now)

    update_default(50, token: original_token)

    expect(response).to have_http_status(:conflict)
    expect(settings.reload.default_table_page_size).to eq(10)
    expect(GeneralSettingAuditEvent.count).to eq(0)
  end

  it 'does not announce a successful change or create an audit event for a no-op' do
    update_default(10)

    expect(response).to redirect_to(admin_general_settings_path)
    expect(flash[:swal_message]).to be_nil
    expect(GeneralSettingAuditEvent.count).to eq(0)
  end

  it 'returns a model error with conflict status instead of overwriting a newer preference' do
    token = settings.updated_at.utc.iso8601(6)
    settings.update!(default_table_page_size: 25)

    update_default(50, token:)

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include('changed in another session')
    expect(settings.reload.default_table_page_size).to eq(25)
    expect(GeneralSettingAuditEvent.count).to eq(0)
  end

  it 'allows a conflict to be retried after refreshing the version' do
    token = settings.updated_at.utc.iso8601(6)
    settings.update!(default_table_page_size: 25)

    update_default(50, token:)
    expect(response).to have_http_status(:conflict)

    update_default(50)
    expect(response).to redirect_to(admin_general_settings_path)
    expect(settings.reload.default_table_page_size).to eq(50)
    expect(GeneralSettingAuditEvent.last.new_page_size).to eq(50)
  end

  it 'offers an explicit recovery form for an organization missing initial settings' do
    currency = settings.base_currency
    organization.update!(onboarding_status: :completed, onboarding_completed_at: Time.current)
    settings.really_destroy!

    get admin_general_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Complete this organization')
    expect(response.body).to include('organization_setting[base_currency_id]')
    expect(response.body).to include('organization_setting[timezone]')
    expect(response.body).to include('organization_setting[payment_method]')

    patch admin_general_settings_path, params: {
      organization_setting: { base_currency_id: currency.id, timezone: 'UTC',
                              payment_method: 'cash', default_table_page_size: 25 }
    }

    expect(response).to redirect_to(admin_general_settings_path)
    expect(organization.organization_settings.active_records.sole).to have_attributes(
      base_currency: currency, timezone: 'UTC', payment_method: 'cash', default_table_page_size: 25
    )
  end

  it 'renders a model error for an unsupported payment method during initial recovery' do
    currency = settings.base_currency
    settings.really_destroy!

    expect do
      patch admin_general_settings_path, params: {
        organization_setting: {
          base_currency_id: currency.id, timezone: 'UTC',
          payment_method: 'crypto', default_table_page_size: 25
        }
      }
    end.not_to change(OrganizationSetting, :count)

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    field = document.at_css('select[name="organization_setting[payment_method]"]')
    expect(field['aria-invalid']).to eq('true')
    expect(field['aria-describedby']).to include('organization_setting_payment_method_error')
    expect(document.at_css('#organization_setting_payment_method_error').text).to include('Payment method')
  end

  it 'rejects missing payment method and an inactive currency during initial recovery' do
    currency = settings.base_currency
    settings.really_destroy!
    currency.update!(active: false)

    patch admin_general_settings_path, params: {
      organization_setting: {
        base_currency_id: currency.id, timezone: 'UTC',
        payment_method: '', default_table_page_size: 25
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#organization_setting_payment_method_error')).to be_present
    expect(document.at_css('#organization_setting_base_currency_error')).to be_present
    expect(organization.organization_settings.active_records).to be_empty
  end

  it 'validates each recovery field on the server without creating incomplete settings' do
    settings.really_destroy!

    patch admin_general_settings_path, params: {
      organization_setting: { base_currency_id: '', timezone: '', payment_method: '',
                              default_table_page_size: 99 }
    }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#organization_setting_base_currency_error')).to be_present
    expect(document.at_css('#organization_setting_timezone_error')).to be_present
    expect(document.at_css('#organization_setting_payment_method_error')).to be_present
    expect(document.at_css('#organization_setting_default_table_page_size_error')).to be_present
    expect(organization.organization_settings.active_records).to be_empty
  end

  it 'limits recovery to the selected organization when a user has two memberships' do
    currency = settings.base_currency
    other = create(:organization)
    create(:organization_membership, user:, organization: other)
    create(:user_role, user:, organization: other, system_role: user.user_roles.active.first.system_role)
    patch admin_select_organization_path(other)

    get admin_general_settings_path
    expect(response).to have_http_status(:ok)

    patch admin_general_settings_path, params: {
      organization_setting: { base_currency_id: currency.id, timezone: 'UTC',
                              payment_method: 'cash', default_table_page_size: 15 },
      organization_id: organization.id
    }

    expect(response).to redirect_to(admin_general_settings_path)
    expect(other.organization_settings.active_records.sole.default_table_page_size).to eq(15)
    expect(settings.reload.default_table_page_size).to eq(10)
  end

  it 'updates only the selected organization even when another id is submitted' do
    other = create(:organization)
    other_settings = create(:organization_setting, organization: other, default_table_page_size: 50)
    create(:organization_membership, user:, organization: other)
    create(:user_role, user:, organization: other, system_role: user.user_roles.active.first.system_role)

    patch admin_select_organization_path(other)
    patch admin_general_settings_path,
          params: { organization_setting: { default_table_page_size: 15 },
                    expected_settings_updated_at: other_settings.reload.updated_at.utc.iso8601(6),
                    organization_id: organization.id }

    expect(response).to redirect_to(admin_general_settings_path)
    expect(other_settings.reload.default_table_page_size).to eq(15)
    expect(settings.reload.default_table_page_size).to eq(10)
    expect(GeneralSettingAuditEvent.last.organization).to eq(other)
  end

  it 'does not permit an administrator from another organization to edit this one' do
    other = create(:organization)
    other_settings = create(:organization_setting, organization: other)
    create(:organization_membership, user:, organization: other)
    patch admin_select_organization_path(other)

    get admin_general_settings_path
    expect(response).to have_http_status(:forbidden)

    patch admin_general_settings_path,
          params: { organization_setting: { default_table_page_size: 50 },
                    expected_settings_updated_at: other_settings.updated_at.utc.iso8601(6) }
    expect(response).to have_http_status(:forbidden)
    expect(other_settings.reload.default_table_page_size).to eq(10)
  end

  it 'rejects changes to organizations without membership' do
    foreign = create(:organization)
    foreign_settings = create(:organization_setting, organization: foreign)
    patch admin_select_organization_path(foreign)

    expect(response).to have_http_status(:not_found)
    sign_in user
    update_default(50)

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

    update_default(25)
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
