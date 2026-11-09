# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branding settings editor', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: admin)
    create(:user_role, user: admin, system_role: role)
    permission = Permission.find_or_create_by!(code: 'email_branding.manage') do |record|
      record.name = 'Manage email branding'
      record.module_name = 'Communication'
      record.status = :active
    end
    SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    Warden.test_mode!
    login_as(admin, scope: :user)
  end

  after do
    page.current_window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'announces an invalid logo and clears the error after a valid upload' do
    page.current_window.resize_to(390, 844)
    visit edit_admin_email_branding_settings_path
    field = '#email_branding_setting_logo'
    expect(page).to have_css("#{field}[aria-invalid='false']")

    Tempfile.create(['oversized-email-logo', '.png']) do |file|
      file.binmode
      file.write('0' * (2.megabytes + 1))
      file.flush
      attach_file('email_branding_setting_logo', file.path)

      expect(page).to have_css("#{field}[aria-invalid='true']")
      expect(page).to have_css('#branding-logo-client-error[role="alert"]', text: /Organization logo/)
      expect(find(field)['aria-describedby'].split).to include('branding-logo-guidance', 'branding-logo-client-error')
      expect(find(field).value).to be_blank
    end

    png = Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
    )
    Tempfile.create(['valid-email-logo', '.png']) do |file|
      file.binmode
      file.write(png)
      file.flush
      attach_file('email_branding_setting_logo', file.path)

      expect(page).to have_css("#{field}[aria-invalid='false']")
      expect(page).to have_css('#branding-logo-client-error', visible: :hidden)
      expect(find(field)['aria-describedby'].split).to eq(['branding-logo-guidance'])
      expect(page).to have_css('[data-email-branding-target="logoName"]', text: 'valid-email-logo')
    end

    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
    expect(EmailBrandingSetting.find_by(organization:)).to be_nil
  end
end
