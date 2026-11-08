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

  it 'offers predefined and already-used categories in a dropdown' do
    get new_admin_email_template_path
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('select#email_template_category')).to be_present
    expect(document.css('select#email_template_category option').pluck('value'))
      .to include('transactional', 'security', 'notifications')
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

  it 'validates a draft preview without treating its original version number as a duplicate' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    post preview_draft_admin_email_template_path(template, version_id: draft.id), params: {
      email_template_version: {
        subject: 'Current unsaved preview',
        html_body: '<p>Current unsaved preview</p>',
        text_body: 'Current unsaved preview',
        allowed_variables_csv: ''
      }
    }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('subject')).to eq('Current unsaved preview')
    expect(draft.reload.subject).to eq('Order')
  end

  it 'rejects an excessively long unsaved preview without persisting it' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    post preview_draft_admin_email_template_path(template, version_id: draft.id), params: {
      email_template_version: {
        subject: 'x' * 251, html_body: '<p>Valid preview</p>', text_body: 'Valid preview',
        allowed_variables_csv: ''
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
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

  it 'accepts an explicit language independently of the interface locale' do
    post admin_email_templates_path, params: {
      email_template: { key: 'order_en', name: 'English order', category: 'transactional', locale: 'en' }
    }
    expect(response).to have_http_status(:redirect)
    expect(EmailTemplate.find_by!(key: 'order_en', organization:).locale).to eq('en')
  end

  it 'renders the creation form and rejects invalid template details' do
    get new_admin_email_template_path
    expect(response).to have_http_status(:ok)
    post admin_email_templates_path, params: {
      email_template: { key: 'Invalid key', name: '', category: 'transactions', locale: 'es' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#email_template_name_error')).to be_present
    expect(document.at_css('#email-template-errors-title')).to be_nil
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

  it 'shows a published email preview and the template identity without exposing the raw HTML' do
    template = create_template(organization:)
    version = template.new_draft!(actor: administrator)
    version.update!(subject: 'Published subject', html_body: '<p>Hello {{recipient_name}}</p>',
                    text_body: 'Hello {{recipient_name}}', allowed_variables: ['recipient_name'])
    version.publish!(actor: administrator)

    get admin_email_template_path(template)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('#email-template-overview-title')).to be_present
    expect(page.at_css('#email-template-content-title')).to be_present
    content = page.at_css('section[aria-labelledby="email-template-content-title"]')
    expect(content.parent['class']).to include('space-y-5')
    expect(content.parent['class']).not_to include('grid')
    expect(content.at_css('[data-email-template-detail-target="frame"]')['class'])
      .to include('max-w-[920px]')
    expect(content.at_css('#email-template-show-frame')['class']).to include('sm:h-[860px]')
    expect(page.at_css('#email-template-show-frame[sandbox]')).to be_present
    expect(page.at_css('#email-template-show-frame')['srcdoc']).to include('Usuario de ejemplo')
    expect(page.at_css('#email-template-show-frame')['srcdoc']).to include('<p>Hello')
    expect(page.at_css('#email-template-show-frame')['srcdoc']).to include('</p>')
    expect(page.at_css('button[aria-controls="email-template-show-frame"][aria-pressed="true"]')).to be_present
    expect(page.at_css('details pre').text).to include('Usuario de ejemplo')
    expect(page.text).to include('Published subject')
  end

  it 'places the catalog back button in the detail header actions' do
    template = create_template(organization:)

    get admin_email_template_path(template)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    heading = document.at_css('main > header')
    actions = heading.at_css('div.ml-auto')
    back = actions.css('a').first
    expect(back['href']).to eq(admin_email_templates_path)
    expect(back.text.strip).to eq(I18n.t('admin.email_templates.back'))
    expect(back['class']).to include('border-slate-200', 'ml-auto')
    expect(back['data-loading-message']).to eq(I18n.t('admin.action_loader.returning'))
    breadcrumb = document.at_css('nav[aria-label] a[href="/admin/email_templates"]')
    expect(breadcrumb.text.strip).to eq(I18n.t('admin.breadcrumbs.controllers.email_templates'))
    expect(heading.at_css('div.min-w-0 a')).to be_nil
  end

  it 'keeps Volver at the right of every email template subpage header' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    draft = template.new_draft!(actor: administrator)

    pages = [
      [new_admin_email_template_path, admin_email_templates_path],
      [admin_email_template_path(template), admin_email_templates_path],
      [edit_admin_email_template_path(template), admin_email_template_path(template)],
      [preview_admin_email_template_path(template, version_id: published.id), admin_email_template_path(template)],
      [compare_admin_email_template_path(template, left: published.id, right: draft.id),
       admin_email_template_path(template)]
    ]

    pages.each do |url, destination|
      get url
      expect(response).to have_http_status(:ok)
      header = Nokogiri::HTML(response.body).at_css('main > header')
      expect(header).to be_present
      expect(header['class']).to include('justify-between', 'flex-wrap')
      back = header.at_css("a[data-loading-message][href='#{destination}']")
      expect(back).to be_present
      expect(back['class']).to include('ml-auto', 'border-slate-200')
      expect(back.text.strip).to eq(I18n.t('admin.email_templates.back'))
      expect(header.element_children.first.css('a[data-loading-message]')).to be_empty
      expect(header.element_children.first.at_css('h1')).to be_present
    end
  end

  it 'renders the complete Delta POS logo in the published email preview' do
    template = create_template(organization:)
    version = template.new_draft!(actor: administrator)
    version.update!(
      html_body: EmailTemplates::DraftStarter.html('es'),
      text_body: EmailTemplates::DraftStarter.plain('es'),
      allowed_variables: %w[platform_logo recipient_name organization_name primary_color secondary_color footer_text]
    )
    version.publish!(actor: administrator)

    get admin_email_template_path(template)

    preview = Nokogiri::HTML(response.body).at_css('#email-template-show-frame')
    expect(preview).to be_present
    expect(preview['srcdoc']).to include('delta-pos-email-logo')
    expect(preview['srcdoc']).not_to include('LOGOTIPO COMPLETO.jpeg')
  end

  it 'shows Deltín and a clear next action when the template is not published' do
    template = create_template(organization:)

    get admin_email_template_path(template)

    page = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(page.at_css('#email-template-show-frame')).to be_nil
    expect(page.at_css("img[alt=\"#{I18n.t('admin.email_templates.deltin_alt')}\"]")).to be_present
    expect(page.text).to include(I18n.t('admin.email_templates.detail_no_version'))
    expect(page.at_css('#email-test-title')).to be_present
    expect(page.at_css('input[name="email"]')).to be_nil
  end

  it 'keeps audit history private without the audit-view permission' do
    template = create_template(organization:)
    template.audit!(action: 'created', actor: administrator)
    permission = Permission.find_or_create_by!(code: 'email_template_audits.view') do |entry|
      entry.name = 'View template audit history'
      entry.module_name = 'Communication'
      entry.status = :active
    end
    SystemRolePermission.where(system_role: role, permission:).destroy_all

    get admin_email_template_path(template)

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('#email-audit-title')).to be_nil

    SystemRolePermission.with_deleted.find_by!(system_role: role, permission:).update!(deleted_at: nil)

    get admin_email_template_path(template)

    expect(Nokogiri::HTML(response.body).at_css('#email-audit-title')).to be_present
    expect(response.body).to include(I18n.t('admin.email_templates.audit_actions.created'))
  end

  it 'does not send email tests after a template has been archived' do
    template = create_template(organization:)
    template.new_draft!(actor: administrator).publish!(actor: administrator)
    template.update!(status: 'archived', enabled: false)

    get admin_email_template_path(template)
    expect(Nokogiri::HTML(response.body).at_css('input[name="email"]')).to be_nil

    post send_test_admin_email_template_path(template), params: { email: administrator.email }

    expect(response).to redirect_to(admin_email_template_path(template))
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.test_not_published'))
    expect(template.audits.where(action: 'test_queued')).not_to exist
  end

  it 'requires permission to browse historical versions even when preview is allowed' do
    template = create_template(organization:)
    version = template.new_draft!(actor: administrator)
    version.publish!(actor: administrator)
    permission = Permission.find_by!(code: 'email_templates.versions')
    SystemRolePermission.where(system_role: role, permission:).destroy_all

    get preview_admin_email_template_path(template, version_id: version.id)
    expect(response).to have_http_status(:forbidden)

    get preview_admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
  end

  it 'validates the test recipient with ActiveModel and shows an inline field error' do
    template = create_template(organization:)
    template.new_draft!(actor: administrator).publish!(actor: administrator)

    post send_test_admin_email_template_path(template), params: { email: '' }
    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    error = page.at_css('#email_templates_test_recipient_email_error')
    expect(error).to be_present
    expect(error.text).to start_with(I18n.t('admin.email_templates.test_recipient'))
    expect(page.at_css('form[novalidate]')).to be_present
    expect(template.audits.where(action: 'test_queued')).not_to exist
  end

  it 'shows version history and reuses the current editable draft' do
    template = create_template(organization:)
    get admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
    expect { get edit_admin_email_template_path(template) }.not_to change(template.versions, :count)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect { post start_draft_admin_email_template_path(template) }.to change(template.versions, :count).by(1)
    expect(response).to redirect_to(edit_admin_email_template_path(template))
    expect { post start_draft_admin_email_template_path(template) }.not_to change(template.versions, :count)
    get edit_admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
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
    expect(flash[:swal_message]).to be_present
    draft = template.new_draft!(actor: administrator)
    post restore_admin_email_template_path(template, version_id: draft.id)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect(flash[:swal_message]).to be_present
  end

  it 'highlights only the newest editable draft in version history' do
    template = create_template(organization:)
    template.new_draft!(actor: administrator)
    latest = template.new_draft!(actor: administrator)
    get admin_email_template_path(template)

    document = Nokogiri::HTML(response.body)
    tags = document.css('[data-current-email-draft]')
    expect(tags.size).to eq(1)
    expect(tags.first['data-current-email-draft']).to eq(latest.id.to_s)
  end

  it 'offers any historical version in the comparison selector' do
    template = create_template(organization:)
    first = template.new_draft!(actor: administrator)
    first.publish!(actor: administrator)
    second = template.new_draft!(actor: administrator)
    third = template.new_draft!(actor: administrator)
    get admin_email_template_path(template)
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('select[name="left"] option').pluck('value'))
      .to include(first.id.to_s, second.id.to_s, third.id.to_s)
    get compare_admin_email_template_path(template, left: first.id, right: third.id)
    expect(response).to have_http_status(:ok)
  end

  it 'rejects selecting the same email version on both sides' do
    template = create_template(organization:)
    version = template.new_draft!(actor: administrator)
    get compare_admin_email_template_path(template, left: version.id, right: version.id)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect(flash[:swal_message]).to eq(I18n.t('admin.email_templates.compare_distinct'))
  end

  it 'highlights differences between subjects when comparing versions' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    changed = template.new_draft!(actor: administrator)
    changed.update!(subject: 'A different subject')

    get compare_admin_email_template_path(template), params: { left: published.id, right: changed.id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.email_templates.compare_changed'))
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

  it 'shows the audited version number alongside a lifecycle event' do
    template = create_template(organization:)
    version = template.new_draft!(actor: administrator)
    template.audit!(action: 'draft_updated', actor: administrator, version:)
    permission = Permission.find_or_create_by!(code: 'email_template_audits.view') do |entry|
      entry.name = 'View email template audits'
      entry.module_name = 'Communication'
      entry.status = :active
    end
    SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    get admin_email_template_path(template)

    expect(response.body).to include('v1')
    expect(response.body).to include(I18n.t('admin.email_templates.audit_actions.draft_updated'))
  end

  it 'queues a published test message and reports invalid recipients' do
    template = create_template(organization:)
    template.new_draft!(actor: administrator).publish!(actor: administrator)
    expect do
      post send_test_admin_email_template_path(template), params: { email: administrator.email }
    end.to have_enqueued_job(EmailTemplates::TestDeliveryJob).with(template.id, administrator.id, administrator.email)
    expect(response).to redirect_to(admin_email_template_path(template))
    expect(template.audits.where(action: 'test_queued')).to exist
    post send_test_admin_email_template_path(template), params: { email: 'invalid' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('#email_templates_test_recipient_email_error')).to be_present
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

  it 'renders accessible language and status filters and applies both on the server' do
    draft = create_template(organization:)
    draft.update!(name: 'Draft mail')
    published = EmailTemplate.create!(
      organization:, key: 'published_mail', name: 'Published mail', locale: 'en',
      category: 'transactional', status: 'draft',
      subject: 'Hello', html_body: '<p>Hello</p>', text_body: 'Hello', enabled: false
    )
    published.new_draft!(actor: administrator).publish!(actor: administrator)

    get admin_email_templates_path, params: { q: 'mail', locale: 'en', status: 'published' }

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('select#locale')).to be_present
    expect(document.at_css('select#status')).to be_present
    expect(document.at_css('label[for="q"]')).to be_present
    expect(document.at_css('form[data-controller="email-template-filters"]')).to be_present
    expect(document.text).to include('Published mail')
    expect(document.text).not_to include('Draft mail')
  end

  it 'keeps every active filter when changing pages and bounds oversized page numbers' do
    21.times do |index|
      EmailTemplate.create!(
        organization:, key: "mail_notice_#{index}", name: "Mail notice #{index}",
        locale: 'en', category: 'transactional', status: 'draft',
        subject: 'Hello', html_body: '<p>Hello</p>', text_body: 'Hello', enabled: false
      )
    end

    get admin_email_templates_path, params: { q: 'Mail notice', locale: 'en', status: 'draft' }

    document = Nokogiri::HTML(response.body)
    next_link = document.css('a').find { |link| link.text.include?(I18n.t('admin.pagination.next')) }
    expect(next_link).to be_present
    query = Rack::Utils.parse_query(URI.parse(next_link['href']).query)
    expect(query).to include('page' => '2', 'q' => 'Mail notice', 'locale' => 'en', 'status' => 'draft')

    get admin_email_templates_path,
        params: { q: 'Mail notice', locale: 'en', status: 'draft', page: '9999' }
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('nav[aria-label] [aria-current="page"]')
      .map(&:text)).to include('3')
    expect(response.body).not_to include(I18n.t('admin.email_templates.empty_title'))
  end

  it 'shows branded draft creation inputs and localizes the initial draft subject' do
    get new_admin_email_template_path

    document = Nokogiri::HTML(response.body)
    expect(document.at_css('select#email_template_locale')).to be_present
    expect(document.at_css('input#email_template_key')).to be_present

    post admin_email_templates_path, params: {
      email_template: { key: 'welcome_mail', name: 'Welcome mail', category: 'transactional', locale: 'ko' }
    }
    template = EmailTemplate.find_by!(key: 'welcome_mail', organization:)
    expect(template.locale).to eq('ko')
    expect(template.subject).to eq(I18n.t('admin.email_templates.default_subject', locale: template.locale))
  end

  it 'starts new templates with an editable branded email in the active locale' do
    %w[es en ko].each do |locale|
      expect(EmailTemplates::DraftStarter.html(locale)).to include('src="{{platform_logo}}"')
      expect(EmailTemplates::DraftStarter.html(locale)).to include('width="320"')
      expect(EmailTemplates::DraftStarter.html(locale)).to include('{{recipient_name}}')
      expect(EmailTemplates::DraftStarter.plain(locale)).to include('{{recipient_name}}')
    end

    post admin_email_templates_path, params: {
      email_template: { key: 'new_branded', name: 'Branded draft', category: 'transactional' }
    }
    expect(response).to have_http_status(:redirect)
    template = EmailTemplate.find_by!(key: 'new_branded', organization:)
    expect(template.html_body).to include('{{platform_logo}}')
    expect(template.html_body).to include('width="320"')
    expect(template.text_body).to include('{{organization_name}}')
    expect(template.versions.order(:version_number).last.allowed_variables)
      .to include('platform_logo', 'recipient_name', 'organization_name')
  end

  it 'shows the creation workflow, localized guidance and accessible required inputs' do
    get new_admin_email_template_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('#email-template-identity-title')).to be_present
    expect(page.at_css('#email-template-delivery-title')).to be_present
    expect(page.at_css('#email-template-guidance-title')).to be_present
    expect(page.at_css('#email-template-create-actions button[type="submit"]')).to be_present
    expect(page.at_css("img[alt=\"#{I18n.t('admin.email_templates.deltin_alt')}\"]")).to be_present
    expect(page.at_css('input#email_template_key')).to be_present
    expect(page.at_css('input#email_template_key[pattern]')).to be_nil
    expect(page.at_css('[data-controller="email-template-identity"]')).to be_present
    expect(page.at_css('select#email_template_locale')).to be_present
    expect(page.css('select#email_template_locale option').pluck('value')).to match_array(%w[es en ko])
    expect(page.text).to include(I18n.t('admin.email_templates.automatic_locale_hint'))
  end

  it 'keeps invalid identity input visible with field-level errors' do
    post admin_email_templates_path, params: {
      email_template: { key: 'invalid-key', name: '', category: '', locale: 'es' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('#email-template-key-hint')).to be_present
    expect(page.at_css('input#email_template_key')['value']).to eq('invalid-key')
    expect(page.at_css('input#email_template_key')['aria-invalid']).to eq('true')
    expect(page.at_css('#email-template-errors-title')).to be_nil
    expect(page.at_css('#email_template_key_error')).to be_present
    expect(page.at_css('#email_template_name_error')).to be_present
    expect(EmailTemplate.where(key: 'invalid-key')).to be_empty
  end

  it 'does not create a global template from an unchecked form without an organization' do
    role.update!(code: 'super_admin')
    administrator.organization_memberships.destroy_all

    post admin_email_templates_path, params: {
      email_template: { key: 'unchecked_global', name: 'Unchecked', category: 'security', locale: 'es' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.email_templates.organization_required'))
    expect(EmailTemplate.global.where(key: 'unchecked_global')).to be_empty
  end

  it 'keeps test sending disabled until publication and restricts the recipient for administrators' do
    template = create_template(organization:)

    get admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('input[name="email"]')).to be_nil

    template.new_draft!(actor: administrator).publish!(actor: administrator)
    get admin_email_template_path(template)

    input = Nokogiri::HTML(response.body).at_css('input[name="email"]')
    expect(input).to be_present
    expect(input['readonly']).not_to be_nil
    expect(input['value']).to eq(administrator.email)
  end

  it 'offers device switching for the draft preview and does not preview an unknown version' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    get edit_admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('button[data-action="click->email-template-preview#showDesktop"]')).to be_present
    expect(document.at_css('button[data-action="click->email-template-preview#showMobile"]')).to be_present
    expect(document.css('iframe[sandbox]').size).to eq(2)

    draft.publish!(actor: administrator)
    get preview_admin_email_template_path(template), params: { version_id: draft.id + 10_000 }
    expect(response).to have_http_status(:not_found)
  end

  it 'continues directly into draft editing after creating a template' do
    post admin_email_templates_path, params: {
      email_template: { name: 'Welcome team', key: 'welcome_team', category: 'notifications' }
    }

    template = EmailTemplate.find_by!(key: 'welcome_team', organization:)
    expect(response).to redirect_to(edit_admin_email_template_path(template))
  end

  it 'presents Deltín and the final identity review in the guided creation flow' do
    get new_admin_email_template_path

    page = Nokogiri::HTML(response.body)
    expect(page.css("nav[aria-label=\"#{I18n.t('admin.email_templates.workflow_label')}\"] li").size).to eq(3)
    expect(page.at_css('#email-template-guidance-title')).to be_present
    expect(page.at_css('#email-template-review-title')).to be_present
    expect(page.at_css('[data-email-template-identity-target="summaryKey"]')).to be_present
    expect(page.css('select#email_template_category option').pluck('value')).to include('security')
    expect(page.at_css('main[data-loading-scope="true"] aside')).to be_nil
    expect(page.at_css('button[data-turbo-submits-with]')).to be_present
    expect(page.at_css('#email-template-create-actions')).to be_present
  end

  it 'exposes variable tools and a safe live preview while editing a draft' do
    template = create_template(organization:)
    template.new_draft!(actor: administrator)

    get edit_admin_email_template_path(template)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    form = page.at_css('form[data-controller~="email-template-editor"]')
    expect(form).to be_present
    expect(form['data-controller']).to include('email-template-preview')
    expect(page.at_css('button[data-variable="platform_logo"][type="button"]')).to be_present
    expect(page.at_css('input[data-email-template-editor-target="variables"]')).to be_present
    expect(page.css('iframe[sandbox]').size).to eq(2)
    expect(page.at_css('nav li[aria-current="step"]')).to be_present
  end

  it 'offers explicit publication only when previewing a draft with permission' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    get preview_admin_email_template_path(template, version_id: draft.id)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    publish_path = publish_admin_email_template_path(template, version_id: draft.id)
    expect(page.at_css("form[action='#{publish_path}']")).to be_present

    draft.publish!(actor: administrator)
    get preview_admin_email_template_path(template, version_id: draft.id)
    expect(Nokogiri::HTML(response.body).css("form[action='#{publish_path}']")).to be_empty
  end

  it 'shows an accessible device switcher for a saved email preview' do
    template = create_template(organization:)
    template.new_draft!(actor: administrator).publish!(actor: administrator)

    get preview_admin_email_template_path(template)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.css('iframe[sandbox]').size).to eq(1)
    expect(page.at_css('iframe#preview-saved-frame')['srcdoc']).to include('Order')
    expect(page.at_css('button[data-action="click->email-template-detail#showMobile"]')).to be_present
    expect(page.at_css('details pre')).to be_present
  end

  it 'renders both selected email versions rather than only displaying HTML source' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    draft = template.new_draft!(actor: administrator)
    draft.update!(subject: 'Second design')

    get compare_admin_email_template_path(template), params: { left: published.id, right: draft.id }

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.css('iframe[sandbox]').size).to eq(2)
    expect(page.text).to include('Second design')
    expect(page.css('main .divide-y details summary').size).to eq(4)
    expect(page.at_css('nav li[aria-current="step"]')).to be_present
  end

  it 'has matching, nonempty email catalog translations for es, en, and ko' do
    paths = lambda do |hash, prefix = ''|
      hash.flat_map do |key, value|
        current = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
        value.is_a?(Hash) ? paths.call(value, current) : [current]
      end
    end

    locales = %i[es en ko].map { |locale| I18n.t('admin.email_templates', locale:) }
    expect(locales.map { |hash| paths.call(hash).sort }.uniq.size).to eq(1)
    locales.each do |hash|
      expect(hash.dig(:languages, :es)).to be_present
      expect(hash.dig(:status_labels, :published)).to be_present
      expect(hash.dig(:settings_fields, :reply_to)).to be_present
    end
  end

  it 'uses localized email template attribute names in validation errors' do
    attributes = %i[name key category locale]
    %i[es en ko].each do |locale|
      I18n.with_locale(locale) do
        attributes.each do |attribute|
          expect(EmailTemplate.human_attribute_name(attribute)).to eq(
            I18n.t("admin.email_templates.columns.#{attribute}")
          )
        end
      end
    end
  end

  it 'requires update permission to restore a published version' do
    template = create_template(organization:)
    published = template.new_draft!(actor: administrator)
    published.publish!(actor: administrator)
    permission = Permission.find_by!(code: 'email_templates.update')
    SystemRolePermission.where(system_role: role, permission:).destroy_all

    post restore_admin_email_template_path(template, version_id: published.id)

    expect(response).to have_http_status(:forbidden)
    expect(template.versions.where(status: 'draft')).to be_empty
  end

  it 'rejects undeclared placeholders in an unsaved preview without saving the draft' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)

    post preview_draft_admin_email_template_path(template, version_id: draft.id), params: {
      email_template_version: {
        subject: 'Hello {{recipient_name}}', html_body: '<p>{{recipient_name}}</p>',
        text_body: 'Hello {{recipient_name}}', allowed_variables_csv: ''
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq(I18n.t('admin.email_templates.preview_undeclared_variables'))
    expect(draft.reload.subject).to eq('Order')
  end

  it 'filters advanced category, scope and dates inside the authorized tenant' do
    own = create_template(organization:)
    own.update!(category: 'billing', name: 'Local billing')
    foreign = create_template(organization: other_organization)
    foreign.update!(category: 'billing', name: 'Private billing')

    get admin_email_templates_path, params: {
      q: 'billing', category: 'billing', scope: 'organization',
      updated_from: 1.day.ago.to_date.iso8601, updated_to: 1.day.from_now.to_date.iso8601
    }

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    expect(doc.text).to include('Local billing')
    expect(doc.text).not_to include('Private billing')
    expect(doc.at_css('select#category')).to be_present
    expect(doc.at_css('select#scope')).to be_present
    expect(doc.at_css('input#updated_from[type="date"]')).to be_present
    expect(doc.at_css('input#updated_to[type="date"]')).to be_present
    expect(doc.css('a[aria-label]').pluck('aria-label')).to include(
      I18n.t('admin.email_templates.remove_filter', name: I18n.t('admin.email_templates.filter_names.category'))
    )
  end

  it 'uses the users-style selectable page size and numbered navigation' do
    12.times do |index|
      EmailTemplate.create!(
        organization:, key: "page_notice_#{index}", name: "Page notice #{index}",
        locale: 'en', category: 'transactional', status: 'draft',
        subject: 'Notice', html_body: '<p>Notice</p>', text_body: 'Notice', enabled: false
      )
    end
    get admin_email_templates_path, params: { per_page: '5', q: 'Page notice', page: '2' }

    doc = Nokogiri::HTML(response.body)
    expect(doc.css('tbody tr').size).to eq(5)
    expect(doc.at_css('select#email-templates-per-page')['data-table-page-size-key-value']).to eq('email_templates')
    expect(doc.css('nav[aria-label] [aria-current="page"]').map(&:text)).to include('2')
    expect(doc.text).to include(I18n.t('admin.email_templates.range', first: 6, last: 10, total: 12))
    expect(doc.at_css('turbo-frame#email_templates_list')).to be_present
  end

  it 'renders compact accessible row actions without expanding the table row' do
    create_template(organization:)
    get admin_email_templates_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('[data-controller="email-template-actions"]')).to be_present
    expect(doc.at_css('[data-email-template-actions-target="button"][aria-expanded="false"]')).to be_present
    expect(doc.at_css('[data-email-template-actions-target="panel"][hidden]')).to be_present
  end

  it 'exposes authorized edit and archive actions from the catalog' do
    template = create_template(organization:)
    get admin_email_templates_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css("form[action='#{start_draft_admin_email_template_path(template)}']")).to be_present
    archive_action = "form[action='#{archive_admin_email_template_path(template)}'] " \
                     "input[name='_method'][value='patch']"
    expect(doc.at_css(archive_action)).to be_present

    archive_permission = Permission.find_by!(code: 'email_templates.archive')
    SystemRolePermission.where(system_role: role, permission: archive_permission).destroy_all
    get admin_email_templates_path
    archived_form = "form[action='#{archive_admin_email_template_path(template)}']"
    expect(Nokogiri::HTML(response.body).at_css(archived_form)).to be_nil
  end

  it 'removes a template without erasing its immutable history' do
    template = create_template(organization:)
    draft = template.new_draft!(actor: administrator)
    template.audit!(action: 'created', actor: administrator)

    delete admin_email_template_path(template)

    expect(response).to have_http_status(:see_other)
    expect(template.reload).to have_attributes(status: 'archived', enabled: false)
    expect(template.versions.find(draft.id)).to be_present
    expect(template.audits.where(action: 'created')).to exist
    expect(template.audits.where(action: 'archived')).to exist
    get admin_email_templates_path
    expect(Nokogiri::HTML(response.body).css('tbody tr').map(&:text).join).not_to include(template.name)
    get admin_email_templates_path, params: { status: 'archived' }
    expect(Nokogiri::HTML(response.body).css('tbody tr').map(&:text).join).to include(template.name)
  end

  it 'rejects removing other organizations templates and missing permissions' do
    foreign = create_template(organization: other_organization)
    delete admin_email_template_path(foreign)
    expect(response).to have_http_status(:not_found)
    own = create_template(organization:)
    archive_permission = Permission.find_by!(code: 'email_templates.archive')
    SystemRolePermission.where(system_role: role, permission: archive_permission).destroy_all
    expect(SystemRolePermission.where(system_role: role, permission: archive_permission)).to be_empty
    expect(administrator.reload.permission?('email_templates.archive')).to be(false)
    expect(EmailTemplatePolicy.new(administrator, own).destroy?).to be(false)
    delete admin_email_template_path(own)
    expect(response).to have_http_status(:forbidden), "Redirected to: #{response.location}"
    expect(own.reload.status).to eq('draft')
  end

  it 'does not crash when advanced dates are invalid' do
    get admin_email_templates_path, params: { updated_from: 'invalid', updated_to: 'bad' }
    expect(response).to have_http_status(:ok)
  end

  it 'translates known template categories in the catalog' do
    template = create_template(organization:)

    get admin_email_templates_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.email_templates.categories.transactions'))
    expect(response.body).not_to include('>transactions</span>')

    get admin_email_template_path(template)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.email_templates.categories.transactions'))
  end

  it 'personalizes a global published template for the current organization only' do
    global = EmailTemplate.create!(
      organization: nil, key: 'welcome_alert', name: 'Global welcome',
      locale: 'es', category: 'transactional', status: 'draft', enabled: false,
      subject: 'Global greeting', html_body: '<p>Hello {{recipient_name}}</p>',
      text_body: 'Hello {{recipient_name}}'
    )
    global.new_draft!(actor: administrator).publish!(actor: administrator)

    post personalize_admin_email_template_path(global)

    local = EmailTemplate.find_by!(organization:, key: global.key, locale: global.locale)
    expect(response).to redirect_to(edit_admin_email_template_path(local))
    expect(local).to have_attributes(status: 'draft', enabled: false, source_template_id: global.id)
    expect(local.versions.pluck(:status)).to eq(['draft'])
    expect(local.versions.first.html_body).to eq(global.published_version.html_body)
    expect(local.audits.where(action: 'personalized')).to exist
    expect(global.reload).to have_attributes(status: 'published', enabled: true)
    expect(EmailTemplate.resolve(key: global.key, locale: 'es', organization:)).to eq(global)

    post personalize_admin_email_template_path(global)
    expect(EmailTemplate.where(organization:, key: global.key, locale: global.locale).count).to eq(1)

    local.versions.first.publish!(actor: administrator)
    expect(EmailTemplate.resolve(key: global.key, locale: 'es', organization:)).to eq(local)
    expect(EmailTemplate.resolve(key: global.key, locale: 'es', organization: other_organization)).to eq(global)

    patch archive_admin_email_template_path(local)
    expect(EmailTemplate.resolve(key: global.key, locale: 'es', organization:)).to eq(global)
    expect(local.reload.status).to eq('archived')

    patch reactivate_admin_email_template_path(local)
    expect(local.reload).to have_attributes(status: 'draft', enabled: false)
    expect(local.audits.where(action: 'reactivated')).to exist
    expect(EmailTemplate.resolve(key: global.key, locale: 'es', organization:)).to eq(global)
  end

  it 'rejects customizing an unpublished template and archiving critical global emails' do
    draft = EmailTemplate.create!(
      key: 'unpublished_system_example', name: 'System draft',
      locale: 'ko', category: 'security', status: 'draft', enabled: false,
      subject: 'Draft', html_body: '<p>Draft</p>', text_body: 'Draft'
    )

    post personalize_admin_email_template_path(draft)
    expect(response).to have_http_status(:forbidden)

    EmailTemplate.ensure_invitation_template!
    global = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')
    patch archive_admin_email_template_path(global)
    expect(response).to have_http_status(:forbidden)
    expect(global.reload).to have_attributes(status: 'published', enabled: true)
  end

  it 'filters templates by their original source and shows a creation action for globals' do
    global = EmailTemplate.create!(
      organization: nil, key: 'global_origin', name: 'Global origin', locale: 'en',
      category: 'transactional', status: 'draft', enabled: false,
      subject: 'Global', html_body: '<p>Global</p>', text_body: 'Global'
    )
    global.new_draft!(actor: administrator).publish!(actor: administrator)
    post personalize_admin_email_template_path(global)
    local = EmailTemplate.find_by!(organization:, key: global.key, locale: global.locale)

    get admin_email_templates_path, params: { origin: 'customized' }
    page = Nokogiri::HTML(response.body)
    expect(page.text).to include(local.name)
    expect(page.text).not_to include('unrelated_not_existing')
    expect(page.at_css('select[name="origin"] option[selected]')['value']).to eq('customized')
    expect(page.text).to include(I18n.t('admin.email_templates.origins.customized'))

    get admin_email_templates_path, params: { origin: 'system' }
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css("form[action='#{personalize_admin_email_template_path(global)}']")).to be_present
    expect(doc.at_css("form[action='#{archive_admin_email_template_path(global)}']")).to be_nil
  end

  it 'deactivates and reactivates published organization templates without changing versions' do
    template = create_template(organization:)
    version = template.new_draft!(actor: administrator)
    version.publish!(actor: administrator)

    patch deactivate_admin_email_template_path(template)
    expect(response).to have_http_status(:see_other)
    expect(template.reload).to have_attributes(status: 'inactive', enabled: false)
    expect(template.published_version).to eq(version)
    expect(template.audits.where(action: 'deactivated')).to exist

    patch activate_admin_email_template_path(template)
    expect(response).to have_http_status(:see_other)
    expect(template.reload).to have_attributes(status: 'published', enabled: true)
    expect(template.published_version).to eq(version)
    expect(template.audits.where(action: 'activated')).to exist
  end
  it 'does not allow customizing global templates without an accessible organization' do
    global = EmailTemplate.create!(
      key: 'no_organization_copy', name: 'System notice', locale: 'es',
      category: 'security', subject: 'Notice', html_body: '<p>Notice</p>',
      text_body: 'Notice', status: 'draft', enabled: false
    )
    global.new_draft!(actor: administrator).publish!(actor: administrator)
    administrator.organization_memberships.destroy_all

    post personalize_admin_email_template_path(global)

    expect(response).to have_http_status(:forbidden)
    expect(EmailTemplate.where(source_template: global)).to be_empty
  end

  it 'blocks root administrators from archiving or deactivating essential global templates' do
    role.update!(code: 'super_admin')
    EmailTemplate.ensure_invitation_template!
    global = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')

    patch archive_admin_email_template_path(global)
    expect(response).to have_http_status(:forbidden)

    patch deactivate_admin_email_template_path(global)
    expect(response).to have_http_status(:forbidden)
    expect(global.reload).to have_attributes(status: 'published', enabled: true)
  end
  it 'hides destructive controls on protected system templates' do
    role.update!(code: 'super_admin')
    EmailTemplate.ensure_invitation_template!
    template = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')

    get admin_email_templates_path, params: { q: 'user_invitation', origin: 'system' }

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    archive_action = "form[action='#{archive_admin_email_template_path(template)}']"
    deactivate_action = "form[action='#{deactivate_admin_email_template_path(template)}']"
    expect(document.at_css(archive_action)).to be_nil
    expect(document.at_css(deactivate_action)).to be_nil
    expect(document.text).to include(I18n.t('admin.email_templates.origins.system'))
  end
end
