# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplatePolicy do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:user) { create(:user, system_roles: [role]) }

  before do
    create(:organization_membership, user:, organization:)
    %w[access update publish].each do |action|
      permission = Permission.find_or_create_by!(code: "email_templates.#{action}") do |record|
        record.name = "Email #{action}"
        record.module_name = 'Communication'
        record.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
  end

  def template_for(organization)
    EmailTemplate.new(
      organization:, key: 'security_notice', name: 'Security',
      locale: 'es', category: 'security', subject: 'Alert',
      html_body: '<p>Alert</p>', text_body: 'Alert'
    )
  end

  it 'does not allow editing global templates or another organization' do
    expect(described_class.new(user, template_for(nil)).update?).to be(false)
    expect(described_class.new(user, template_for(other_organization)).update?).to be(false)
    expect(described_class.new(user, template_for(organization)).update?).to be(true)
  end
end
