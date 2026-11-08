# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email settings policies' do
  let(:organization) { create(:organization) }
  let(:foreign_organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:user) { create(:user, system_roles: [role]) }

  before do
    create(:organization_membership, user:, organization:)
    %w[email_settings.manage email_branding.manage email_setting_audits.view].each do |code|
      permission = Permission.find_or_create_by!(code:) do |record|
        record.name = code
        record.module_name = 'Communication'
        record.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
  end

  it 'authorizes only accessible organization senders' do
    expect(EmailSenderSettingPolicy.new(user, EmailSenderSetting.new(organization:)).update?).to be(true)
    expect(EmailSenderSettingPolicy.new(user, EmailSenderSetting.new(organization: foreign_organization)).update?).to be(false)
    expect(EmailSenderSettingPolicy.new(user, EmailSenderSetting.new).update?).to be(false)
  end

  it 'protects global branding from ordinary administrators' do
    expect(EmailBrandingSettingPolicy.new(user, EmailBrandingSetting.new(organization:)).edit?).to be(true)
    expect(EmailBrandingSettingPolicy.new(user, EmailBrandingSetting.new(organization: foreign_organization)).edit?).to be(false)
    expect(EmailBrandingSettingPolicy.new(user, EmailBrandingSetting.new).edit?).to be(false)
    role.update!(code: 'super_admin')
    expect(EmailBrandingSettingPolicy.new(user, EmailBrandingSetting.new).edit?).to be(true)
  end

  it 'scopes audit history by accessible organization and permission' do
    local = EmailSettingAudit.create!(organization:, actor: user, setting_type: 'sender',
                                      changeset: { 'display_name' => %w[A B] })
    EmailSettingAudit.create!(organization: foreign_organization, actor: user,
                              setting_type: 'branding', changeset: { 'display_name' => %w[A B] })
    expect(EmailSettingAuditPolicy::Scope.new(user, EmailSettingAudit).resolve).to contain_exactly(local)

    permission = Permission.find_by!(code: 'email_setting_audits.view')
    SystemRolePermission.where(system_role: role, permission:).destroy_all
    expect(EmailSettingAuditPolicy.new(user, EmailSettingAudit).index?).to be(false)
    expect(EmailSettingAuditPolicy::Scope.new(user, EmailSettingAudit).resolve).to be_empty
  end
end
