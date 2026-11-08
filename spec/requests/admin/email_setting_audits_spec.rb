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

  it 'aligns Volver on the right for branding and sender settings' do
    [edit_admin_email_branding_settings_path, edit_admin_email_sender_settings_path].each do |url|
      get url
      expect(response).to have_http_status(:ok)
      header = Nokogiri::HTML(response.body).at_css('main > header')
      expect(header['class']).to include('justify-between', 'flex-wrap')
      back = header.at_css("a[data-loading-message][href='#{admin_email_templates_path}']")
      expect(back).to be_present
      expect(back['class']).to include('ml-auto', 'border-slate-200')
      expect(back.text.strip).to eq(I18n.t('admin.email_templates.back'))
    end
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
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.saved'))
    expect(administrator.notifications.last.event).to have_attributes(record_type: 'EmailSenderSetting')
    expect(administrator.notifications.last.event.params[:action]).to eq('sender_updated')
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
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.saved'))
    expect(administrator.notifications.last.event).to have_attributes(record_type: 'EmailBrandingSetting')
    expect(administrator.notifications.last.event.params[:action]).to eq('branding_updated')

    patch admin_email_branding_settings_path, params: {
      email_branding_setting: { primary_color: 'javascript:alert(1)' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(EmailSettingAudit.where(setting_type: 'branding', organization:).count).to eq(1)
    expect(administrator.notifications.count).to eq(1)
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
      changeset: { 'display_name' => %w[Before After] }
    )

    expect(audit.destroy).to be_falsey
    expect(EmailSettingAudit.exists?(audit.id)).to be(true)
  end

  it 'renders the branding editor and rejects invalid sender settings' do
    get edit_admin_email_branding_settings_path
    expect(response).to have_http_status(:ok)
    patch admin_email_sender_settings_path, params: {
      email_sender_setting: { from_address: 'invalid-address' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(EmailSettingAudit.where(setting_type: 'sender')).to be_empty
  end

  it 'does not grant global branding access to an ordinary administrator' do
    get edit_admin_email_branding_settings_path, params: { global: '1' }
    expect(response).to have_http_status(:ok)
    patch admin_email_branding_settings_path, params: {
      global: '1', email_branding_setting: { display_name: 'Local identity' }
    }
    expect(response).to have_http_status(:redirect)
    expect(EmailBrandingSetting.find_by!(organization:).display_name).to eq('Local identity')
    expect(EmailBrandingSetting.find_by(organization_id: nil)).to be_nil
  end

  it 'requires explicit permissions for both settings editors' do
    role.system_role_permissions.destroy_all
    get edit_admin_email_branding_settings_path
    expect(response).to have_http_status(:forbidden)
    get edit_admin_email_sender_settings_path
    expect(response).to have_http_status(:forbidden)
  end

  it 'allows a root administrator to audit global branding changes' do
    role.update!(code: 'super_admin')
    patch admin_email_branding_settings_path, params: {
      global: '1', email_branding_setting: { display_name: 'Platform identity' }
    }
    expect(response).to have_http_status(:redirect)
    expect(EmailBrandingSetting.find_by!(organization_id: nil).display_name).to eq('Platform identity')
    expect(EmailSettingAudit.where(organization_id: nil, setting_type: 'branding')).to exist
  end

  it 'records logo replacement without storing the uploaded file in the audit' do
    png = Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
    )
    Tempfile.create(['branding-logo', '.png']) do |file|
      file.binmode
      file.write(png)
      file.flush
      patch admin_email_branding_settings_path, params: {
        email_branding_setting: { display_name: 'Tenant', logo: Rack::Test::UploadedFile.new(file.path, 'image/png') }
      }
    end
    expect(response).to have_http_status(:redirect)
    expect(EmailBrandingSetting.find_by!(organization:).logo).to be_attached
    expect(EmailSettingAudit.find_by!(organization:, setting_type: 'branding').changeset)
      .to include('logo_updated' => true)
  end

  it 'renders an accessible branding editor with live preview and existing logos' do
    branding = EmailBrandingSetting.create!(organization:, display_name: 'North Shop')
    png = Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
    )
    branding.logo.attach(io: StringIO.new(png), filename: 'logo.png', content_type: 'image/png')
    get edit_admin_email_branding_settings_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-controller="email-branding"]')).to be_present
    expect(page.at_css('[data-email-branding-target="previewButton"]')).to be_present
    expect(page.css('input[type="color"][data-email-branding-target="picker"]').size).to eq(3)
    expect(page.at_css('input#email_branding_setting_support_email[type="email"]')).to be_present
    expect(page.at_css('input#email_branding_setting_support_url[type="url"]')).to be_present
    expect(page.at_css('input#email_branding_setting_privacy_url[type="url"]')).to be_present
    expect(page.at_css('input[name="remove_logo"][type="checkbox"]')).to be_present
    platform_alt = I18n.t('admin.email_templates.branding_platform_logo_alt')
    platform_logos = page.css('img').select { |image| image['alt'] == platform_alt }
    expect(platform_logos.length).to eq(2)
    platform_logos.each do |image|
      expect(image['src']).to include(EmailTemplates::Branding::PLATFORM_LOGO_WEB.delete_suffix('.svg'))
      expect(image['src']).to match(/\.svg(?:\?.*)?\z/)
    end
    expect(response.body).not_to include('LOGOTIPO COMPLETO.jpeg', 'NEXO POS')
  end

  it 'validates accessibility and contact details on the server without notifying' do
    expect do
      patch admin_email_branding_settings_path, params: {
        email_branding_setting: {
          display_name: 'North Shop', button_color: '#FFFFFF',
          support_email: 'not-an-email', support_url: 'http://insecure.example.org'
        }
      }
    end.not_to(change { administrator.notifications.count })

    expect(response).to have_http_status(:unprocessable_content)
    expect(EmailSettingAudit.where(organization:, setting_type: 'branding')).to be_empty
    expect(EmailBrandingSetting.find_by(organization:)).to be_nil
  end

  it 'removes an optional organization logo without deleting the required platform logo' do
    branding = EmailBrandingSetting.create!(organization:, display_name: 'North Shop')
    png = Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
    )
    branding.logo.attach(io: StringIO.new(png), filename: 'logo.png', content_type: 'image/png')

    patch admin_email_branding_settings_path, params: {
      remove_logo: '1', email_branding_setting: { display_name: 'North Shop' }
    }

    expect(response).to have_http_status(:redirect)
    expect(branding.reload.logo).not_to be_attached
    expect(EmailSettingAudit.find_by!(organization:, setting_type: 'branding').changeset)
      .to include('logo_removed' => true)
  end
end
