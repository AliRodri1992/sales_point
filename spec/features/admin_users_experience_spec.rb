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
