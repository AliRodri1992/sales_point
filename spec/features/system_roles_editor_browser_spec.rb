# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Grouped role permissions', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:admin) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations', code: 'operations') }
  let!(:view_permission) do
    create(:permission, code: 'suppliers.contacts.view', name: 'View supplier contacts', module_name: 'Proveedores')
  end
  let!(:create_permission) do
    create(:permission, code: 'suppliers.contacts.create', name: 'Create supplier contacts', module_name: 'Proveedores')
  end
  let!(:other_permission) { create(:permission, code: 'sales.access', module_name: 'Ventas') }

  before do
    create(:organization_membership, user: admin)
    create(:user_role, user: admin, system_role: create(:system_role, :system, code: 'super_admin'))
    Warden.test_mode!
    login_as(admin, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'opens a locally assigned role in the editable permissions workspace' do
    create(:user_role, user: admin, system_role: role)

    visit system_role_path(role)

    expect(page).to have_css('[data-permissions-mode="edit"]')
    expect(page).to have_css('h1', text: 'Manage permissions', exact_text: true)
    expect(page).to have_unchecked_field("permission_#{view_permission.id}")
  end

  scenario 'allows an administrator to review and save local permission switches' do
    administrator = create(:user, :english)
    create(:organization_membership, user: administrator)
    create(:user_role, user: administrator, system_role: create(:system_role, :system, code: 'administrator'))
    create(:user_role, user: administrator, system_role: role)
    login_as(administrator, scope: :user)

    visit system_role_path(role)
    expect(page).to have_css('[data-permissions-mode="edit"]')
    expect(page).to have_field('system_role_name', disabled: true)
    check "permission_#{view_permission.id}"
    click_button 'Save permissions'
    within '[role="dialog"]' do
      expect(page).to have_text('suppliers.contacts.view')
      click_button 'Confirm changes'
    end
    expect(page).to have_text('The role permissions were saved.')
    expect(role.permissions.reload).to contain_exactly(view_permission)
    expect(role.permission_audit_events.last.actor).to eq(administrator)
  end

  scenario 'opens a protected role in the read-only permissions workspace' do
    visit system_role_path(admin.system_roles.first)

    expect(page).to have_css('[data-permissions-mode="view"]')
    expect(page).to have_css('h1', text: 'View permissions', exact_text: true)
    expect(page).to have_field("permission_#{view_permission.id}", disabled: true)
    expect(page).to have_no_button('Save permissions', disabled: :all)
    expect(page).to have_no_button('Discard changes', disabled: :all)
    expect(page).to have_no_css('[data-bulk-state]', visible: :all)

    click_button 'Unassigned'
    expect(page).to have_text('No permissions match your search.')

    click_button 'Assigned'
    fill_in 'Search modules or actions', with: 'suppliers.contacts.view'
    expect(page).to have_checked_field("permission_#{view_permission.id}", disabled: true)
    expect(page).to have_no_css("#permission_#{create_permission.id}")
  end

  scenario 'expands the full permission matrix without overflowing a narrow viewport' do
    irregular = create(:permission, code: 'suppliers.contacts.set_primary', module_name: 'Proveedores')
    group = 'details[data-role-permissions-target="group"]'
    page.driver.browser.manage.window.resize_to(390, 844)
    visit system_role_path(role)

    expect(page).to have_button('Collapse all')
    click_button 'Collapse all'
    expect(page).to have_no_css("#{group}[open]")
    click_button 'Expand all'
    expect(page).to have_css("#{group}[open]", count: 2)
    expect(page).to have_unchecked_field("permission_#{irregular.id}")
    [320, 390, 768, 1440].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
    end
  end

  scenario 'counts permission differences and returns to zero when a change is reverted' do
    visit system_role_path(role)
    pending = '[data-role-permissions-target="pending"]'

    expect(page).to have_css(pending, text: /\b0\b/)
    expect(page).to have_button('Save permissions', disabled: true)
    check "permission_#{view_permission.id}"
    expect(page).to have_css(pending, text: /\b1\b/)
    expect(page).to have_button('Save permissions', disabled: false)
    uncheck "permission_#{view_permission.id}"
    expect(page).to have_css(pending, text: /\b0\b/)
    expect(page).to have_button('Save permissions', disabled: true)
  end

  scenario 'reviews permission differences before persisting them to the authorized history' do
    create(:system_role_permission, system_role: role, permission: view_permission)
    visit system_role_path(role)
    uncheck "permission_#{view_permission.id}"
    check "permission_#{create_permission.id}"
    expect(page).to have_css('[data-role-permissions-target="pending"]', text: /\b2\b/)

    click_button 'Save permissions'
    within '[role="dialog"]' do
      expect(page).to have_css('section[aria-labelledby="permission-review-added"] li',
                               text: 'Create supplier contacts suppliers.contacts.create', exact_text: true)
      expect(page).to have_css('section[aria-labelledby="permission-review-removed"] li',
                               text: 'View supplier contacts suppliers.contacts.view', exact_text: true)
      click_button 'Back to permissions'
    end
    expect(page).to have_no_button('Confirm changes')
    expect(page).to have_checked_field("permission_#{create_permission.id}")
    expect(page).to have_unchecked_field("permission_#{view_permission.id}")
    expect(role.permissions.reload).to contain_exactly(view_permission)

    click_button 'Save permissions'
    click_button 'Confirm changes'

    within '#permission-history' do
      expect(page).to have_text('Added: suppliers.contacts.create')
      expect(page).to have_text('Removed: suppliers.contacts.view')
    end
    expect(role.permissions.reload).to contain_exactly(create_permission)
    expect(role.permission_audit_events.count).to eq(1)
    expect(SystemRoleNotification.where(record: role).count).to eq(1)
  end

  scenario 'discards pending permission and metadata changes in place' do
    create(:system_role_permission, system_role: role, permission: view_permission)
    visit system_role_path(role)
    fill_in 'system_role_name', with: 'Unsaved name'
    fill_in 'system_role_description', with: 'Unsaved description'
    uncheck "permission_#{view_permission.id}"
    check "permission_#{create_permission.id}"

    expect(page).to have_button('Discard changes')
    click_button 'Discard changes'

    expect(page).to have_current_path(system_role_path(role))
    expect(page).to have_field('system_role_name', with: 'Operations')
    expect(page).to have_field('system_role_description', with: role.description)
    expect(page).to have_checked_field("permission_#{view_permission.id}")
    expect(page).to have_unchecked_field("permission_#{create_permission.id}")
    expect(page).to have_css('[data-role-permissions-target="pending"]', text: /\b0\b/)
    expect(role.reload.name).to eq('Operations')
    expect(role.permissions.reload).to contain_exactly(view_permission)
    expect(SystemRoleNotification.where(record: role)).to be_empty
  end

  scenario 'selects a module, retains hidden selections and persists them together' do
    visit system_role_path(role)
    click_button 'Grant visible · Suppliers'
    expect(page).to have_css('button[aria-label="Revoke visible · Suppliers"]:focus')
    expect(page).to have_checked_field("permission_#{view_permission.id}")
    expect(page).to have_checked_field("permission_#{create_permission.id}")
    expect(page).to have_unchecked_field("permission_#{other_permission.id}")
    expect(page).to have_css('[data-role-permissions-target="total"]', text: '2')

    uncheck "permission_#{create_permission.id}"
    within find('summary', text: 'Suppliers') do
      expect(page).to have_css('[data-group-count]', text: '1', exact_text: true)
    end
    expect(page).to have_button('Grant visible · Suppliers', disabled: false)
    expect(page).to have_button('Revoke visible · Suppliers', disabled: false)
    fill_in 'Search modules or actions', with: 'Sales'
    expect(page).to have_no_css("#permission_#{view_permission.id}")
    check "permission_#{other_permission.id}"
    click_button 'Save permissions'
    click_button 'Confirm changes'
    expect(page).to have_css('.swal2-popup')
    expect(page).to have_current_path(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(view_permission, other_permission)
  end

  scenario 'supports narrow layouts, empty search and protected roles' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_system_role_path
    expect(page).to have_field('Search modules or actions')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
    fill_in 'Search modules or actions', with: 'no-matching-permissions'
    expect(page).to have_text('No permissions match your search.')
    click_button 'Clear filters'
    expect(page).to have_css("#permission_#{view_permission.id}")

    visit system_role_path(admin.system_roles.first)
    expect(page).to have_field("permission_#{view_permission.id}", disabled: true)
    expect(page).to have_no_button('Save permissions')
  end
  scenario 'uses accessible switches and enables module access with an action' do
    GranularPermissionCatalog.sync!
    permission = Permission.find_by!(code: 'languages.update')
    access = Permission.find_by!(code: 'languages.access')
    visit system_role_path(role)
    expect(page).to have_css('input[role="switch"]', visible: :all)
    check "permission_#{permission.id}"
    expect(page).to have_checked_field("permission_#{access.id}")
    expect(page).to have_css('[data-role-permissions-target="total"]', text: '2')
    click_button 'Save permissions'
    click_button 'Confirm changes'
    expect(page).to have_css('.swal2-popup')
    expect(role.permissions.reload).to contain_exactly(permission, access)
  end
end
