# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Visible-only bulk permission selection', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:actor) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations', code: 'operations') }
  let!(:visible) { create(:permission, code: 'suppliers.contacts.create', module_name: 'Suppliers') }
  let!(:hidden_permission) { create(:permission, code: 'suppliers.contacts.view', module_name: 'Suppliers') }

  before do
    create(:organization_membership, user: actor)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'super_admin'))
    Warden.test_mode!
    login_as(actor, scope: :user)
  end

  after { Warden.test_reset! }

  it 'filters assigned and unassigned permissions without changing the selection' do
    create(:system_role_permission, system_role: role, permission: hidden_permission)
    visit system_role_path(role)

    expect(page).to have_css('button[data-filter-state="all"][aria-pressed="true"]')
    click_button 'Assigned'
    expect(page).to have_css('button[data-filter-state="assigned"][aria-pressed="true"]')
    expect(page).to have_checked_field("permission_#{hidden_permission.id}")
    expect(page).to have_no_css("#permission_#{visible.id}")

    click_button 'Unassigned'
    expect(page).to have_css('button[data-filter-state="unassigned"][aria-pressed="true"]')
    expect(page).to have_unchecked_field("permission_#{visible.id}")
    expect(page).to have_no_css("#permission_#{hidden_permission.id}")

    click_button 'All'
    expect(page).to have_checked_field("permission_#{hidden_permission.id}")
    expect(page).to have_unchecked_field("permission_#{visible.id}")
  end

  it 'revokes grants matching both filters while keeping a hidden grant in the module' do
    create(:system_role_permission, system_role: role, permission: visible)
    create(:system_role_permission, system_role: role, permission: hidden_permission)
    visit system_role_path(role)
    expect(page).to have_css('button[data-filter-state="assigned"]')
    click_button 'Assigned'
    fill_in 'Search modules or actions', with: 'suppliers.contacts.create'
    expect(page).to have_no_css("#permission_#{hidden_permission.id}")
    find('button[data-bulk-state="revoke"]').click

    expect(page).to have_text('No permissions match your search.')
    fill_in 'Search modules or actions', with: ''
    click_button 'All'
    expect(page).to have_unchecked_field("permission_#{visible.id}")
    expect(page).to have_checked_field("permission_#{hidden_permission.id}")
  end

  it 'announces access permissions enabled outside the visible search results' do
    access = create(:permission, code: 'languages.access', module_name: 'Languages')
    edit = create(:permission, code: 'languages.update', module_name: 'Languages')

    visit system_role_path(role)
    fill_in 'Search modules or actions', with: 'languages.update'
    expect(page).to have_no_css("#permission_#{access.id}")
    click_button 'Grant visible · Languages'

    expect(page).to have_checked_field("permission_#{edit.id}")
    expect(page).to have_checked_field("permission_#{access.id}", visible: :all)
    expect(page).to have_css('[data-role-permissions-target="dependencyNotice"]',
                             text: 'languages.access')
    expect(page).to have_css('[data-role-permissions-target="total"]', text: '2')

    click_button 'Review and save'
    click_button 'Confirm changes'
    expect(page).to have_css('.swal2-popup')
    expect(page).to have_current_path(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(access, edit)
  end

  it 'revokes dependent grants when a bulk action turns off their module access' do
    access = create(:permission, code: 'languages.access', module_name: 'Languages')
    edit = create(:permission, code: 'languages.update', module_name: 'Languages')
    create(:system_role_permission, system_role: role, permission: access)
    create(:system_role_permission, system_role: role, permission: edit)
    create(:system_role_permission, system_role: role, permission: hidden_permission)
    visit system_role_path(role)

    fill_in 'Search modules or actions', with: 'languages.access'
    expect(page).to have_no_css("#permission_#{edit.id}")
    click_button 'Revoke visible · Languages'

    expect(page).to have_unchecked_field("permission_#{access.id}")
    expect(page).to have_unchecked_field("permission_#{edit.id}", visible: :all)
    expect(page).to have_checked_field("permission_#{hidden_permission.id}", visible: :all)
    expect(page).to have_css('[data-role-permissions-target="dependencyNotice"]', text: 'languages.update')
    expect(page).to have_css('[data-role-permissions-target="total"]', text: '1', exact_text: true)
  end

  it 'selects only filtered permissions and leaves hidden permissions disabled' do
    visit system_role_path(role)
    fill_in 'Search modules or actions', with: 'suppliers.contacts.create'
    expect(page).to have_css("#permission_#{visible.id}", visible: :all)
    expect(page).to have_no_css("#permission_#{hidden_permission.id}")
    click_button 'Grant visible · Suppliers'
    click_button 'Review and save'
    click_button 'Confirm changes'
    expect(page).to have_css('.swal2-popup')
    expect(page).to have_current_path(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(visible)
  end
end
