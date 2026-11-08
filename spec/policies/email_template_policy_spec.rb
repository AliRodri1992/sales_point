# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplatePolicy do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:user) { create(:user, system_roles: [role]) }

  before do
    create(:organization_membership, user:, organization:)
    %w[access create update publish archive preview send_test versions].each do |action|
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

  %i[show? update? publish? archive? destroy? preview? send_test? versions?].each do |action|
    it "allows #{action} only within the visible tenant boundaries" do
      expect(described_class.new(user, template_for(organization)).public_send(action)).to be(true)
      expect(described_class.new(user, template_for(other_organization)).public_send(action)).to be(false)
    end
  end

  it 'does not allow removing archived templates again' do
    template = template_for(organization)
    template.status = 'archived'
    expect(described_class.new(user, template).destroy?).to be(false)
  end

  it 'permits global viewing while limiting global changes to root administrators' do
    policy = described_class.new(user, template_for(nil))
    expect(policy.show?).to be(true)
    expect(policy.preview?).to be(true)
    role.update!(code: 'super_admin')
    expect(policy.update?).to be(true)
  end

  it 'denies permissions to inactive users and nonadministrative roles' do
    user.update!(status: :suspended)
    expect(described_class.new(user, template_for(organization)).create?).to be(false)
    user.update!(status: :active)
    user.user_roles.destroy_all
    expect(described_class.new(user, template_for(organization)).create?).to be(false)
    expect(described_class::Scope.new(user, EmailTemplate).resolve).to be_empty
  end

  it 'denies anonymous access and scopes' do
    expect(described_class.new(nil, template_for(organization)).index?).to be_falsey
    expect(described_class::Scope.new(nil, EmailTemplate).resolve).to be_empty
  end
  it 'allows published global copies but protects essential global emails' do
    global = template_for(nil)
    global.status = 'published'
    global.enabled = true
    global.id = 87
    version = EmailTemplateVersion.new(email_template: global, version_number: 1, status: 'published',
                                        subject: 'Hello', html_body: '<p>Hello</p>', text_body: 'Hello')
    allow(global).to receive(:published_version).and_return(version)
    expect(described_class.new(user, global).personalize?).to be(true)

    global.key = 'user_invitation'
    expect(described_class.new(user, global).archive?).to be(false)
    expect(described_class.new(user, global).destroy?).to be(false)
  end

  it 'allows restoring archived organization templates but prevents publishing until restored' do
    template = template_for(organization)
    template.status = 'archived'
    policy = described_class.new(user, template)
    expect(policy.reactivate?).to be(true)
    expect(policy.update?).to be(false)
    expect(policy.publish?).to be(false)
  end

end
