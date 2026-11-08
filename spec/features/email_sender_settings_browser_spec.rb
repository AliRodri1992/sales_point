# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sender settings editor', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: admin)
    create(:user_role, user: admin, system_role: role)
    permission = Permission.find_or_create_by!(code: 'email_settings.manage') do |record|
      record.name = 'Manage email settings'
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

  scenario 'updates the live sender preview while editing without sending email' do
    page.current_window.resize_to(390, 844)
    visit edit_admin_email_sender_settings_path

    expect(page).to have_css('#sender-preview-title')
    fill_in 'email_sender_setting_display_name', with: 'North Shop'
    fill_in 'email_sender_setting_from_address', with: 'INFO@NORTH.EXAMPLE'
    fill_in 'email_sender_setting_reply_to', with: 'support@north.example'

    expect(page).to have_css('[data-email-sender-target="previewName"]', text: 'North Shop')
    expect(page).to have_css('[data-email-sender-target="previewFrom"]', text: 'info@north.example')
    expect(page).to have_css('[data-email-sender-target="previewReply"]', text: 'support@north.example')
    expect(page).to have_css('[data-email-sender-target="previewDomain"]', text: 'north.example')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)

    click_button I18n.t('admin.email_templates.save', locale: :en)

    expect(page).to have_css('#sender-preview-title')
    expect(EmailSenderSetting.find_by!(organization:).from_address).to eq('info@north.example')
    expect(EmailSenderSetting.find_by!(organization:).domain_status).to eq('unverified')
  end
end
