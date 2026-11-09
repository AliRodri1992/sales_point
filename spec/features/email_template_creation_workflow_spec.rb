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
    category = find('#email_template_category', visible: :all).find(:xpath, '..')
    category.find('button[data-delta-select-generated]').click
    category.find('[role="option"]', text: I18n.t('admin.email_templates.categories.security', locale: :en)).click
    expect(find('#email_template_category', visible: :all).value).to eq('security')
    expect(find('[data-email-template-identity-target="summaryKey"]').text).to eq('welcome_staff')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)

    find('#email-template-create-actions button[type="submit"]').click

    expect(page).to have_css('#template-editor-title')
    template = EmailTemplate.find_by!(key: 'welcome_staff', organization:)
    expect(template.html_body).to include('{{platform_logo}}')
    expect(template.versions.where(status: 'draft')).to exist
  end

  scenario 'displays an accessible compact catalog on a mobile viewport' do
    EmailTemplate.create!(
      organization:, key: 'mobile_notification', name: 'Mobile notice', locale: 'en',
      category: 'notifications', status: 'draft', enabled: false,
      subject: 'Notice', html_body: '<p>Notice</p>', text_body: 'Notice'
    )
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_email_templates_path

    expect(page).to have_css('table tbody tr', count: 1)
    expect(page).to have_css('table tbody tr a', text: 'Mobile notice')
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const table = document.querySelector('table')
        const headers = Array.from(table.querySelectorAll('thead th'))
        const hidden = headers.filter(cell => getComputedStyle(cell).display === 'none')
        return hidden.length === 5 && document.documentElement.scrollWidth <= window.innerWidth + 2
      })()
    JS
  end

  scenario 'refreshes date validation feedback outside the list frame while keeping live search' do
    visit admin_email_templates_path

    expect(page).to have_css('form[data-email-template-filters-target]', count: 0)
    expect(page).to have_css('input#updated_from')
    page.execute_script(<<~JS)
      document.querySelector('#updated_from').value = '2026-12-31'
      const to = document.querySelector('#updated_to')
      to.value = '2026-01-01'
      to.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    expect(page).to have_css('#email-updated-to-error', text: /.+/)
    expect(page).to have_css('#updated_to[aria-invalid="true"]')

    page.execute_script(<<~JS)
      const to = document.querySelector('#updated_to')
      to.value = '2027-01-01'
      to.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    expect(page).to have_no_css('#email-updated-to-error')
    expect(page).to have_css('#updated_to[aria-invalid="false"]')
    expect(page).to have_css('form[data-turbo-frame="email_templates_list"]')
  end

  scenario 'keeps unsaved changes when canceling the Delta POS navigation confirmation' do
    template = EmailTemplate.create!(
      organization:, key: 'unsaved_notification', name: 'Unsaved notice', locale: 'en',
      category: 'notifications', status: 'draft', enabled: false,
      subject: 'Notice', html_body: '<p>Notice</p>', text_body: 'Notice'
    )
    template.new_draft!(actor: admin)
    visit edit_admin_email_template_path(template)
    find('#email_template_version_subject').set('Pending changes')
    find('main > header a[href]', match: :first).click

    expect(page).to have_css('.delta-confirm-popup')
    find('.delta-confirm-cancel').click
    expect(page).to have_css('#template-editor-title')
    expect(find('#email_template_version_subject').value).to eq('Pending changes')
  end

  scenario 'keeps server field errors visible without duplicating them in the live preview' do
    template = EmailTemplate.create!(
      organization:, key: 'server_error_notice', name: 'Notice', locale: 'en',
      category: 'notifications', status: 'draft', enabled: false,
      subject: 'Notice', html_body: '<p>Notice</p>', text_body: 'Notice'
    )
    template.new_draft!(actor: admin)
    visit edit_admin_email_template_path(template)

    find('#email_template_version_subject').set('')
    click_button I18n.t('admin.email_templates.save_draft', locale: :en)

    expect(page).to have_css('#email_template_version_subject_error', text: /blank|empty/i)
    expect(page).to have_css('#email_template_version_subject[aria-invalid="true"]')
    expect(find('#email_template_version_subject')['aria-describedby'].split)
      .to include('email_template_version_subject_error')
    expect(page).to have_no_css('[data-email-preview-field-error]')

    find('#email_template_version_subject').set('Corrected without saving')
    expect(page).to have_no_css('#email_template_version_subject_error')
    expect(page).to have_css('#email_template_version_subject[aria-invalid="false"]')
    expect(find('#email_template_version_subject')['aria-describedby'].to_s).not_to include('subject_error')
    expect(template.versions.where(status: 'draft').first.reload.subject).to eq('Notice')

    find('#email_template_version_subject').set('{{not_approved}}')
    expect(page).to have_css(
      '#email_template_version_allowed_variables_error[data-email-preview-field-error]', count: 1
    )
    expect(page).to have_css('#email_template_version_allowed_variables_csv[aria-invalid="true"]')
    expect(find('#email_template_version_allowed_variables_csv')['aria-describedby'].split)
      .to include('email_template_version_allowed_variables_error')
    find('#email_template_version_subject').set('Corrected again')
    expect(page).to have_no_css('#email_template_version_allowed_variables_error')
    expect(page).to have_css('#email_template_version_allowed_variables_csv[aria-invalid="false"]')
    expect(template.versions.where(status: 'draft').first.reload.subject).to eq('Notice')
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
    expect(page).to have_css('[data-email-template-editor-target="variablePills"]', text: 'platform_logo')
    expect(page).to have_css('#email-preview-title')
  end
end
