# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email catalog permission seeds' do
  let(:administrator_role) { create(:system_role, :system, code: 'administrator') }
  let(:super_admin_role) { create(:system_role, :system, code: 'super_admin') }

  it 'restores full email administration to existing roles without duplicate assignments' do
    roles = [administrator_role, super_admin_role]
    permission_codes = %w[
      email_templates.access email_templates.create email_templates.update
      email_templates.publish email_templates.archive email_templates.preview
      email_templates.send_test email_templates.versions email_branding.manage
      email_settings.manage email_template_audits.view
    ]

    load Rails.root.join('db/seeds/email_catalog.rb')

    roles.each do |role|
      expect(role.permissions.where(code: permission_codes).distinct.count).to eq(permission_codes.size)
    end

    first_counts = roles.to_h { |role| [role.id, role.system_role_permissions.count] }
    load Rails.root.join('db/seeds/email_catalog.rb')

    roles.each do |role|
      expect(role.system_role_permissions.count).to eq(first_counts.fetch(role.id))
    end
  end
end
