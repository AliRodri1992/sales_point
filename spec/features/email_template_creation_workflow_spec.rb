# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email template creation workflow', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, :english) }

  before do
    create(:organization_membership, user: admin, organization:)
    create(:user_role, user: admin, system_role: role)
    %w[email_templates.access email_templates.create email_templates.update
       email_templates.preview email_templates.versions].each do |code|
      permission = Permission.find_or_create_by!(code:) do |entry|
        entry.name = code
        entry.module_name = 'Communication'
        entry.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
    Warden.test_mode!
    login_as(admin, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'creates an accessible, branded first draft from the mobile setup screen' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_admin_email_template_path

    expect(page).to have_css('#email-template-guidance-title')
    expect(page).to have_css('#email-template-review-title')
    find('#email_template_name').set('Welcome staff')

    expect(find('#email_template_key').value).to eq('welcome_staff')
    find('button[data-category-value="security"]').click
    expect(find('#email_template_category').value).to eq('security')
    expect(find('[data-email-template-identity-target="summaryKey"]').text).to eq('welcome_staff')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)

    find('#email-template-create-actions button[type="submit"]').click

    expect(page).to have_css('#email-template-overview-title')
    template = EmailTemplate.find_by!(key: 'welcome_staff', organization:)
    expect(template.html_body).to include('{{platform_logo}}')
    expect(template.versions.where(status: 'draft')).to exist
  end

  scenario 'inserts an allowed placeholder into the draft HTML at the cursor' do
    template = EmailTemplate.create!(
      organization:, key: 'staff_news', name: 'Staff news', locale: 'en',
      category: 'notifications', status: 'draft', enabled: false,
      subject: 'Staff news', html_body: '<p>Hello {{recipient_name}}</p>',
      text_body: 'Hello {{recipient_name}}'
    )
    template.new_draft!(actor: admin)

    visit edit_admin_email_template_path(template)

    editor = find('#email_template_version_html_body')
    editor.click
    first('button[data-variable="platform_logo"]').click
    expect(editor.value).to include('{{platform_logo}}')
    expect(find('#email_template_version_allowed_variables_csv').value).to include('platform_logo')
    expect(page).to have_css('#email-preview-title')
  end
end
