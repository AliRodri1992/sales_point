# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin users redesigned screens', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:admin) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: admin)
    create(:user_role, user: admin, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(admin, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'shows useful cards and accessible actions without horizontal overflow on mobile' do
    target = create(:user, username: 'Mobile Employee', email: 'mobile@example.com')
    create(:organization_membership, organization:, user: target)
    page.driver.browser.manage.window.resize_to(390, 844)

    visit admin_users_path

    expect(page).to have_css('#users-filter-search')
    expect(page).to have_css('section[aria-labelledby="users-results-title"]')
    expect(page).to have_css('article[data-skeleton-record]', minimum: 1)
    expect(page).to have_css('a[aria-label="View"]', minimum: 1)
    expect(page).to have_no_css('input[type="radio"]', visible: :all)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
  end

  scenario 'removes a filter chip without losing other active filters on mobile' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_users_path(q: 'example', status: 'active')

    expect(page).to have_css('#users-active-filters a[data-user-filter]', count: 2)
    find('#users-active-filters a[data-user-filter="status"]').click

    expect(page).to have_current_path(admin_users_path(q: 'example'))
    expect(page).to have_css('#users-active-filters a[data-user-filter="q"]')
    expect(page).to have_no_css('#users-active-filters a[data-user-filter="status"]')
    expect(page).to have_field('q', with: 'example')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
  end

  scenario 'places the review near submit and shows Deltín without horizontal overflow' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_admin_user_path

    expect(page).to have_css('#users-create-deltin img[alt="Deltín, the Delta POS mascot"]')
    expect(page).to have_css('#users-review-title', text: 'Before saving')
    expect(page).to have_no_css('.users-create-workspace aside')
    order = page.evaluate_script(<<~JS)
      ['users-create-deltin', 'users-identity-title', 'users-preferences-title', 'users-review-title']
        .map((id) => document.getElementById(id)?.getBoundingClientRect().top)
    JS
    expect(order).to eq(order.sort)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
  end

  scenario 'offers clear role selection feedback and guards against repeated submits' do
    visit new_admin_user_path

    expect(page).to have_css('[data-user-access-target="summary"]', text: 'No roles selected')
    expect(page).to have_css('#user_email[maxlength="254"]')
    expect(page).to have_css('input[data-user-access-target="submitButton"]')

    fill_in 'Find a role', with: 'role-that-does-not-exist'
    expect(page).to have_css('[data-user-access-target="empty"]:not(.hidden)', text: /No roles match/)
  end

  scenario 'shows a dynamic review, default invitation language and theme swatch' do
    visit new_admin_user_path

    fill_in 'Email address', with: 'team@example.com'
    expect(page).to have_css('[data-user-access-target="reviewEmail"]', text: 'team@example.com')
    expect(page).to have_css('[data-user-access-target="reviewUserType"]', text: 'Employee')
    expect(find('[data-user-access-target="themeSwatch"]')[:style]).to include('background-color')
    expect(page).to have_css('[data-user-access-target="roleWarning"]:not(.hidden)')
    expect(page).to have_css('[data-user-access-target="reviewLanguage"]')
  end

  scenario 'places model-aligned email and type errors immediately below fields' do
    visit new_admin_user_path

    fill_in 'Email address', with: 'invalid-address'
    find('#user_email').send_keys(:tab)
    expect(page).to have_css('[data-user-access-target="emailError"]:not(.hidden)', text: /Email address/)
    expect(page).to have_css('[data-user-access-target="emailError"]:not(.hidden)', text: /invalid/i)

    click_button 'Create user'
    expect(page).to have_css('#user_email.input-field-error')
    expect(page).to have_css('#user_email_error', text: /Email address/)
  end

  scenario 'edits branch access through accessible accordion checkboxes' do
    target = create(:user, username: 'Branch Employee')
    create(:organization_membership, organization:, user: target)
    branch = create(:branch, organization:, name: 'Branch Center')
    branch_role = create(:system_role, :branch, code: 'branch_assistant')

    visit edit_admin_user_path(target)
    expect(page).to have_css('#users-branches-title')
    accordion = find('section[aria-labelledby="users-branches-title"] details', text: branch.name)
    accordion.find('summary').click
    check("user_branch_role_#{branch.id}_#{branch_role.id}")
    click_button 'Save changes'

    expect(page).to have_current_path(admin_user_path(target))
    expect(page).to have_text(branch.name)
    expect(target.user_roles.active.where(branch_id: branch.id).pluck(:system_role_id)).to eq([branch_role.id])
  end

  scenario 'renders field validation directly beneath the email input' do
    target = create(:user, username: 'Validation Employee')
    create(:organization_membership, organization:, user: target)

    visit edit_admin_user_path(target)
    fill_in 'Email address', with: ''
    click_button 'Save changes'

    expect(page).to have_css('#user_email.input-field-error')
    expect(page).to have_css('p[data-server-field-error]', text: /Email/i)
    expect(page).to have_css('#users-identity-title')
  end
  scenario 'presents accessible status actions on narrow screens' do
    role = admin.system_roles.first
    permission = Permission.find_or_create_by!(code: 'users.suspend') do |item|
      item.name = 'Suspend users'
      item.module_name = 'Usuarios'
      item.status = :active
    end
    SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    target = create(:user, username: 'Status Employee')
    create(:organization_membership, organization:, user: target)
    page.driver.browser.manage.window.resize_to(390, 844)

    visit edit_admin_user_status_path(target, transition: 'suspended')
    expect(page).to have_css('label[for="reason"]')
    expect(page).to have_css('label[for="review_at"]')
    expect(page).to have_css('textarea#reason[required]')
    expect(page).to have_no_css('input[type="radio"]', visible: :all)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
  end
end
