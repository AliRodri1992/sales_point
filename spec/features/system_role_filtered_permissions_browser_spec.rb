# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Visible-only bulk permission selection', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:actor) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations', code: 'operations') }
  let!(:visible) { create(:permission, code: 'suppliers.contacts.create', module_name: 'Suppliers') }
  let!(:hidden_permission) { create(:permission, code: 'suppliers.contacts.view', module_name: 'Suppliers') }

  before do
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'super_admin'))
    Warden.test_mode!
    login_as(actor, scope: :user)
  end

  after { Warden.test_reset! }

  it 'selects only filtered permissions and leaves hidden permissions disabled' do
    visit system_role_path(role)
    fill_in 'Search modules or actions', with: 'suppliers.contacts.create'
    expect(page).to have_css("#permission_#{visible.id}", visible: :all)
    expect(page).to have_no_css("#permission_#{hidden_permission.id}")
    check 'Select visible: Suppliers'
    click_button 'Save permissions'
    expect(page).to have_current_path(system_role_path(role))
    expect(role.permissions.reload).to contain_exactly(visible)
  end
end
