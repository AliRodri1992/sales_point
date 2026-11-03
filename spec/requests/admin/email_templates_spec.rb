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
end
