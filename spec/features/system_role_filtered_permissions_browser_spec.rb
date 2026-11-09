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

  it 'announces access permissions enabled outside the visible search results' do
    access = create(:permission, code: 'languages.access', module_name: 'Languages')
    edit = create(:permission, code: 'languages.update', module_name: 'Languages')

    visit system_role_path(role)
    fill_in 'Search modules or actions', with: 'languages.update'
    expect(page).to have_no_css("#permission_#{access.id}")
    check 'Select visible: Languages'

    expect(page).to have_checked_field("permission_#{edit.id}")
    expect(page).to have_checked_field("permission_#{access.id}", visible: :all)
    expect(page).to have_css('[data-role-permissions-target="dependencyNotice"]',
                             text: 'languages.access')
    expect(page).to have_css('[data-role-permissions-target="total"]', text: '2')

    click_button 'Save permissions'
    expect(page).to have_css('.swal2-popup')
    expect(page).to have_current_path(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(access, edit)
  end

  it 'selects only filtered permissions and leaves hidden permissions disabled' do
    visit system_role_path(role)
    fill_in 'Search modules or actions', with: 'suppliers.contacts.create'
    expect(page).to have_css("#permission_#{visible.id}", visible: :all)
    expect(page).to have_no_css("#permission_#{hidden_permission.id}")
    check 'Select visible: Suppliers'
    click_button 'Save permissions'
    expect(page).to have_css('.swal2-popup')
    expect(page).to have_current_path(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(visible)
  end
end
