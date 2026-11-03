# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email settings audit history', type: :request do
  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:administrator) { create(:user, system_roles: [role]) }

  before do
    %w[email_branding.manage email_settings.manage].each do |code|
      permission = Permission.find_or_create_by!(code:) do |record|
        record.name = code
        record.module_name = 'Communication'
        record.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
    create(:organization_membership, organization:, user: administrator)
    sign_in administrator
  end

  it 'records a sender setting update with the actor and organization' do
    patch admin_email_sender_settings_path, params: {
      email_sender_setting: {
        display_name: 'Delta POS',
        from_address: 'notificaciones@example.org',
        reply_to: 'soporte@example.org',
        default_locale: 'es'
      }
    }

    expect(response).to have_http_status(:redirect)
    audit = EmailSettingAudit.find_by!(setting_type: 'sender', organization:)
    expect(audit.actor).to eq(administrator)
    expect(audit.changeset).to include('from_address')
  end

  it 'records a branding update without creating an audit for an invalid update' do
    patch admin_email_branding_settings_path, params: {
      email_branding_setting: {
        display_name: 'Marca personalizada',
        primary_color: '#064e3b',
        secondary_color: '#047857',
        button_color: '#047857'
      }
    }

    expect(response).to have_http_status(:redirect)
    expect(EmailSettingAudit.where(setting_type: 'branding', organization:).count).to eq(1)

    patch admin_email_branding_settings_path, params: {
      email_branding_setting: { primary_color: 'javascript:alert(1)' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(EmailSettingAudit.where(setting_type: 'branding', organization:).count).to eq(1)
  end
  it 'does not display audit history from another organization' do
    foreign = create(:organization)
    EmailSettingAudit.create!(
      organization: foreign, actor: administrator, setting_type: 'sender',
      changeset: { 'from_address' => ['private@another.example', 'private2@another.example'] }
    )

    get edit_admin_email_sender_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('private@another.example')
    expect(response.body).not_to include('private2@another.example')
    expect(response.body).to include(I18n.t('email_setting_audits.heading'))
  end

  it 'prevents deleting audit evidence' do
    audit = EmailSettingAudit.create!(
      organization:, actor: administrator, setting_type: 'sender',
      changeset: { 'display_name' => ['Before', 'After'] }
    )

    expect(audit.destroy).to be_falsey
    expect(EmailSettingAudit.exists?(audit.id)).to be(true)
  end

end
