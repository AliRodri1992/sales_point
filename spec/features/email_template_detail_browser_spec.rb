# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email template detail preview', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, :english) }

  before do
    create(:organization_membership, user: admin, organization:)
    create(:user_role, user: admin, system_role: role)
    %w[email_templates.access email_templates.preview email_templates.versions].each do |code|
      permission = Permission.find_or_create_by!(code:) do |item|
        item.name = code
        item.module_name = 'Communication'
        item.status = :active
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

  scenario 'shows the published email as a large desktop-first reading workspace' do
    template = EmailTemplate.create!(
      organization:, key: 'wide_preview', locale: 'en', name: 'Wide preview',
      category: 'transactional', status: 'draft', enabled: false,
      subject: 'Welcome', html_body: '<p>Hello {{recipient_name}}</p>',
      text_body: 'Hello {{recipient_name}}'
    )
    template.new_draft!(actor: admin).publish!(actor: admin)
    page.driver.browser.manage.window.resize_to(1440, 900)

    visit admin_email_template_path(template)

    expect(page).to have_css('#email-template-show-frame[sandbox]')
    expect(page).to have_css('main > header > div:last-child > a[href="/admin/email_templates"]')
    stage = find('section[aria-labelledby="email-template-content-title"]')
    expect(stage).to have_css('[data-email-template-detail-target="frame"].max-w-\\[920px\\]')
    expect(page).to have_css('#email-template-show-frame')
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const card = document.querySelector('section[aria-labelledby="email-template-content-title"]')
        const frame = document.querySelector('[data-email-template-detail-target="frame"]')
        const iframe = document.querySelector('#email-template-show-frame')
        return card.getBoundingClientRect().width > 1200 &&
          frame.getBoundingClientRect().width >= 850 &&
          iframe.getBoundingClientRect().height >= 800
      })()
    JS
    expect(page).to have_css('#email-template-versions-title')
  end

  scenario 'previews a published email at mobile width without horizontal overflow' do
    template = EmailTemplate.create!(
      organization:, key: 'detail_preview', locale: 'en', name: 'Detail preview',
      category: 'transactional', status: 'draft', enabled: false,
      subject: 'Welcome', html_body: '<p>Hello {{recipient_name}}</p>',
      text_body: 'Hello {{recipient_name}}'
    )
    template.new_draft!(actor: admin).publish!(actor: admin)
    page.driver.browser.manage.window.resize_to(390, 844)

    visit admin_email_template_path(template)

    expect(page).to have_css('#email-template-show-frame[sandbox]')
    expect(page).to have_css('main > header > div:last-child > a[href="/admin/email_templates"]')
    expect(page).to have_css('[data-email-template-detail-target="desktopButton"][aria-pressed="true"]')
    find('[data-email-template-detail-target="mobileButton"]').click
    expect(page).to have_css('[data-email-template-detail-target="mobileButton"][aria-pressed="true"]')
    expect(page.evaluate_script(<<~JS)).to be(true)
      document.querySelector('[data-email-template-detail-target="frame"]')
        .classList.contains('max-w-[375px]')
    JS
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
  end
end
