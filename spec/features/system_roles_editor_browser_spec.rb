# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Grouped role permissions', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:admin) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations', code: 'operations') }
  let!(:view_permission) { create(:permission, code: 'suppliers.contacts.view', module_name: 'Proveedores') }
  let!(:create_permission) { create(:permission, code: 'suppliers.contacts.create', module_name: 'Proveedores') }
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

  scenario 'selects a module, retains hidden selections and persists them together' do
    visit system_role_path(role)
    check 'Select visible: Suppliers'
    expect(page).to have_checked_field("permission_#{view_permission.id}")
    expect(page).to have_checked_field("permission_#{create_permission.id}")
    expect(page).to have_unchecked_field("permission_#{other_permission.id}")
    expect(page).to have_css('[data-role-permissions-target="total"]', text: '2')

    uncheck "permission_#{create_permission.id}"
    group_selector = '[data-select-group][aria-label="Select visible: Suppliers"]'
    expect(find(group_selector).evaluate_script('this.indeterminate')).to be(true)
    fill_in 'Search modules or actions', with: 'Sales'
    expect(page).to have_no_css("#permission_#{view_permission.id}")
    check "permission_#{other_permission.id}"
    click_button 'Save permissions'
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
    fill_in 'Search modules or actions', with: ''
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
    expect(page).to have_css('.swal2-popup')
    expect(role.permissions.reload).to contain_exactly(permission, access)
  end
end
