# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin email templates', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:administrator) { create(:user, system_roles: [role]) }

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

  def create_template(organization:)
    EmailTemplate.create!(
      organization:, key: 'order_notice', name: 'Order notice',
      locale: 'es', category: 'transactions', status: 'draft',
      subject: 'Order', html_body: '<p>Order</p>',
      text_body: 'Order', enabled: false
    )
  end

  it 'lists the catalog and allows its tenant to create a draft' do
    get admin_email_templates_path
    expect(response).to have_http_status(:ok)

    post admin_email_templates_path, params: {
      email_template: { key: 'order_notice', name: 'Order notice', category: 'transactions', locale: 'es' }
    }
    expect(response).to have_http_status(:redirect)
    template = EmailTemplate.find_by!(key: 'order_notice', organization:)
    expect(template.versions.where(status: 'draft')).to exist
    expect(template.published_version).to be_nil
  end

  it 'loads the catalog query and filters only permitted templates' do
    own = create_template(organization:)
    own.update!(name: 'Welcome notice')
    foreign = create_template(organization: other_organization)
    foreign.update!(name: 'Welcome private')

    get admin_email_templates_path, params: { q: 'Welcome', locale: 'es' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Welcome notice')
    expect(response.body).not_to include('Welcome private')
  end

  it 'rejects viewing another organization template by guessed ID' do
    foreign = create_template(organization: other_organization)
    get admin_email_template_path(foreign)
    expect(response).to have_http_status(:not_found)
  end

  it 'publishes only its own draft and records an audit event' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    post publish_admin_email_template_path(template, version_id: draft.id)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect(template.reload.published_version).to eq(draft)
    expect(template.audits.where(action: 'published')).to exist
  end
  it 'previews unsaved draft content without persisting changes' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    post preview_draft_admin_email_template_path(template, version_id: draft.id), params: {
      email_template_version: {
        subject: 'Hola {{recipient_name}}',
        html_body: '<p>Hola {{recipient_name}}</p>',
        text_body: 'Hola {{recipient_name}}',
        allowed_variables_csv: 'recipient_name'
      }
    }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('subject')).to include('Usuario de ejemplo')
    expect(response.parsed_body.fetch('html')).to include('Usuario de ejemplo')
    expect(draft.reload.subject).to eq('Order')
  end

  it 'does not preview unsaved drafts from another organization' do
    foreign = create_template(organization: other_organization)
    draft = foreign.new_draft!(actor: administrator)

    post preview_draft_admin_email_template_path(foreign, version_id: draft.id), params: {
      email_template_version: { subject: 'Access forbidden' }
    }

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects unauthorized placeholders in an unsaved preview' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    post preview_draft_admin_email_template_path(template, version_id: draft.id), params: {
      email_template_version: {
        subject: '{{not_approved}}',
        html_body: '<p>Test</p>',
        text_body: 'Test',
        allowed_variables_csv: 'recipient_name'
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(draft.reload.subject).to eq('Order')
  end

  it 'renders the creation form and rejects invalid template details' do
    get new_admin_email_template_path
    expect(response).to have_http_status(:ok)
    post admin_email_templates_path, params: {
      email_template: { key: 'Invalid key', name: '', category: 'transactions', locale: 'es' }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'allows root administrators to create global templates without an organization' do
    role.update!(code: 'super_admin')
    administrator.organization_memberships.destroy_all
    get new_admin_email_template_path
    expect(response).to have_http_status(:ok)
    post admin_email_templates_path, params: {
      global: '1', email_template: { key: 'global_notice', name: 'Global notice', category: 'security', locale: 'es' }
    }
    expect(response).to have_http_status(:redirect)
    expect(EmailTemplate.global.find_by!(key: 'global_notice').created_by).to eq(administrator)
  end

  it 'requires an organization for ordinary administrators creating templates' do
    administrator.organization_memberships.destroy_all
    get new_admin_email_template_path
    expect(response).to have_http_status(:forbidden)
    post admin_email_templates_path, params: {
      global: '1', email_template: { key: 'forged_global', name: 'Forged', category: 'security', locale: 'es' }
    }
    expect(response).to have_http_status(:forbidden)
    expect(EmailTemplate.global.where(key: 'forged_global')).to be_empty
  end

  it 'shows version history and reuses the current editable draft' do
    template = create_template(organization:)
    get admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
    expect { get edit_admin_email_template_path(template) }.to change(template.versions, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect { get edit_admin_email_template_path(template) }.not_to change(template.versions, :count)
  end

  it 'saves valid draft content and audits the edit' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)
    patch draft_admin_email_template_path(template, version_id: draft.id), params: {
      email_template_version: { subject: 'Updated order', allowed_variables_csv: '' }
    }
    expect(response).to redirect_to(edit_admin_email_template_path(template))
    expect(draft.reload.subject).to eq('Updated order')
    expect(template.audits.where(action: 'draft_updated')).to exist
  end

  it 'keeps invalid draft changes out of storage' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)
    patch draft_admin_email_template_path(template, version_id: draft.id), params: {
      email_template_version: { subject: '' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(draft.reload.subject).to eq('Order')
  end

  it 'protects published content from draft editing and unsaved previews' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    patch draft_admin_email_template_path(template, version_id: published.id), params: {
      email_template_version: { subject: 'Tampered' }
    }
    expect(response).to have_http_status(:forbidden)
    post preview_draft_admin_email_template_path(template, version_id: published.id), params: {
      email_template_version: { subject: 'Tampered' }
    }
    expect(response).to have_http_status(:forbidden)
    expect(published.reload.subject).to eq('Order')
  end

  it 'reports attempts to republish or restore an unpublished version' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    post publish_admin_email_template_path(template, version_id: published.id)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect(flash[:alert]).to be_present
    draft = template.new_draft!(actor: administrator)
    post restore_admin_email_template_path(template, version_id: draft.id)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect(flash[:alert]).to be_present
  end

  it 'restores published content into a new draft and compares versions' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    expect do
      post restore_admin_email_template_path(template, version_id: published.id)
    end.to change(template.versions, :count).by(1)
    restored = template.versions.order(:id).last
    expect(restored).to have_attributes(status: 'draft', subject: published.subject)
    expect(template.audits.where(action: 'restored')).to exist
    get compare_admin_email_template_path(template), params: { left: published.id, right: restored.id }
    expect(response).to have_http_status(:ok)
  end

  it 'previews a selected version or the published fallback' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    get preview_admin_email_template_path(template), params: { version_id: published.id }
    expect(response).to have_http_status(:ok)
    get preview_admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
  end

  it 'reports a missing preview when no published or selected version exists' do
    get preview_admin_email_template_path(create_template(organization:))
    expect(response).to have_http_status(:not_found)
  end

  it 'archives a template and records the change' do
    template = create_template(organization:)
    patch archive_admin_email_template_path(template)
    expect(response).to redirect_to(admin_email_templates_path)
    expect(template.reload).to have_attributes(status: 'archived', enabled: false)
    expect(template.audits.where(action: 'archived')).to exist
  end

  it 'queues a published test message and reports invalid recipients' do
    template = create_template(organization:)
    template.new_draft!(actor: administrator).publish!(actor: administrator)
    expect do
      post send_test_admin_email_template_path(template), params: { email: administrator.email }
    end.to have_enqueued_mail(EmailTemplateTestMailer, :sample).with(template.id, administrator.email)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect(template.audits.where(action: 'test_sent')).to exist
    post send_test_admin_email_template_path(template), params: { email: 'invalid' }
    expect(flash[:alert]).to eq('Invalid recipient')
  end

  it 'never selects a draft version owned by a different template' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)
    foreign = create_template(organization: other_organization).new_draft!(actor: administrator)
    patch draft_admin_email_template_path(template, version_id: foreign.id), params: {
      email_template_version: { subject: 'Cross-template edit' }
    }
    expect(response).to have_http_status(:not_found)
    expect(draft.reload.subject).to eq('Order')
    expect(foreign.reload.subject).to eq('Order')
  end
end
