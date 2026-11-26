# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'System roles directory interface', type: :feature, js: true do
  let!(:actor) { create(:user, :english) }
  let!(:organization) { create(:organization) }
  let!(:super_role) { create(:system_role, :system, code: 'super_admin') }

  before do
    create(:organization_membership, organization:, user: actor)
    create(:user_role, organization:, user: actor, system_role: super_role)
    sign_in actor
  end

  scenario 'creates an inactive role in the accessible modal without modifying role cards' do
    visit system_roles_path
    click_button 'New role'

    expect(page).to have_css('#new-role-dialog[open]', visible: :visible)
    within '#new-role-dialog' do
      fill_in 'Name', with: 'Shift Leader'
      expect(find('input[name="system_role[code]"]').value).to eq('shift_leader')

      find('[data-controller="delta-select"] button[aria-haspopup="listbox"]').click
      find('[role="option"]', text: 'Branch').click
      click_button 'Create role'
    end

    role = SystemRole.find_by!(code: 'shift_leader')
    expect(role).to be_inactive
    expect(page).to have_current_path(system_role_path(role))
  end

  scenario 'keeps the modal open and shows a field error after invalid submission' do
    visit system_roles_path
    click_button 'New role'

    within '#new-role-dialog' do
      fill_in 'Name', with: ''
      fill_in 'Code', with: 'invalid-code'
      click_button 'Create role'
    end

    expect(page).to have_css('#new-role-dialog[open]')
    expect(page).to have_css('#system_role_name_error', visible: :visible)
    expect(page).to have_css('#system_role_code_error', visible: :visible)
  end
end
