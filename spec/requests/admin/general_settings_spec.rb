require 'rails_helper'

RSpec.describe 'Admin general settings', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:settings) { create(:organization_setting, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    role = SystemRole.find_or_create_by!(code: 'administrator') { |record| record.role_type = :system }
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

  it 'returns not found when the organization settings have been archived' do
    settings.update_column(:deleted_at, Time.current)

    get admin_general_settings_path
    expect(response).to have_http_status(:not_found)

    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }
    expect(response).to have_http_status(:not_found)
  end

  it 'denies a system administrator without an active organization membership' do
    user.organization_memberships.update_all(status: 'inactive')

    get admin_general_settings_path

    expect(response).to have_http_status(:forbidden)
  end

  it 'prevents non-administrators from reading or changing general settings' do
    user.user_roles.delete_all
    get admin_general_settings_path
    expect(response).to have_http_status(:forbidden)

    patch admin_general_settings_path, params: { organization_setting: { default_table_page_size: 25 } }
    expect(response).to have_http_status(:forbidden)
    expect(settings.reload.default_table_page_size).to eq(10)
  end
end
