# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email template locale and activity', type: :request do
  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:administrator) { create(:user, :english, system_roles: [role]) }

  before do
    %w[access create update publish versions preview send_test archive].each do |action|
      permission = Permission.find_or_create_by!(code: "email_templates.#{action}") do |record|
        record.name = "Manage email #{action}"
        record.module_name = 'Communication'
        record.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
    create(:organization_membership, user: administrator, organization:)
    sign_in administrator
  end

  def create_draft
    EmailTemplate.create!(
      organization:, key: 'activity_notice', name: 'Activity notice', locale: 'en',
      category: 'transactional', status: 'draft', enabled: false,
      subject: 'Notice', html_body: '<p>Notice</p>', text_body: 'Notice'
    )
  end

  it 'shows the language without an empty option and never trusts the submitted locale' do
    codes = %w[es en ko]
    codes.each do |code|
      language = create(:language, code:, name: code, flag_iso: 'mx')
      administrator.update!(language:)
      get new_admin_email_template_path

      document = Nokogiri::HTML(response.body)
      expect(document.at_css('select#email_template_locale')).to be_nil
      expect(document.at_css('#email-template-language-display').text)
        .to include(I18n.t("admin.email_templates.languages.#{code}", locale: code))

      post admin_email_templates_path, params: {
        email_template: { key: "notice_#{code}", name: 'Localized notice',
                          category: 'security', locale: 'forged_language' }
      }
      expect(response).to have_http_status(:redirect)
      template = EmailTemplate.find_by!(key: "notice_#{code}", organization:)
      expect(template.locale).to eq(code)
      expect(template.subject).to eq(I18n.t('admin.email_templates.default_subject', locale: code))
    end
  end

  it 'shows SweetAlert and saves a database notification when creating a draft' do
    expect do
      post admin_email_templates_path, params: {
        email_template: { key: 'new_notice', name: 'New notice', category: 'security' }
      }
    end.to change { administrator.notifications.count }.by(1)

    template = EmailTemplate.find_by!(key: 'new_notice', organization:)
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.created_toast', locale: :en))
    expect(administrator.notifications.last.event.record).to eq(template)
    expect(administrator.notifications.last.event.params[:action]).to eq('created')
  end

  it 'notifies only after a successful draft update' do
    template = create_draft
    draft = template.new_draft!(actor: administrator)

    expect do
      patch draft_admin_email_template_path(template, version_id: draft.id),
            params: { email_template_version: { subject: 'Revised notice' } }
    end.to change { administrator.notifications.count }.by(1)
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.draft_updated_toast', locale: :en))
    expect(administrator.notifications.last.event.params[:action]).to eq('draft_updated')
  end

  it 'notifies the actor about publication, restoration and archiving' do
    template = create_draft
    version = template.new_draft!(actor: administrator)

    expect do
      post publish_admin_email_template_path(template, version_id: version.id)
    end.to change { administrator.notifications.count }.by(1)
    expect(administrator.notifications.last.event.params[:action]).to eq('published')
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.published', locale: :en))

    expect do
      post restore_admin_email_template_path(template, version_id: version.id)
    end.to change { administrator.notifications.count }.by(1)
    expect(administrator.notifications.last.event.params[:action]).to eq('restored')

    expect do
      patch archive_admin_email_template_path(template)
    end.to change { administrator.notifications.count }.by(1)
    expect(administrator.notifications.last.event.params[:action]).to eq('archived')
  end

  it 'keeps history and notifies the panel when removing a template' do
    template = create_draft
    version = template.new_draft!(actor: administrator)

    expect do
      delete admin_email_template_path(template)
    end.to change { administrator.notifications.count }.by(1)
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.removed', locale: :en))
    expect(template.reload.status).to eq('archived')
    expect(template.versions.find(version.id)).to be_present
    expect(administrator.notifications.last.event.params[:action]).to eq('removed')
  end

  it 'does not notify about failed creation' do
    expect do
      post admin_email_templates_path,
           params: { email_template: { key: 'invalid-key', name: '', category: 'security' } }
    end.not_to change { administrator.notifications.count }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
