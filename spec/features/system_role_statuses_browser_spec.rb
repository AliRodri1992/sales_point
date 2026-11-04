# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Role status review', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:admin) { create(:user, :english) }
  let!(:role) { create(:system_role, :system, name: 'Operations') }
  let!(:permission) { create(:permission, code: 'products.show') }

  before do
    create(:user_role, user: admin, system_role: create(:system_role, :system, code: 'administrator'))
    create(:system_role_permission, system_role: role, permission:)
    Warden.test_mode!
    login_as(admin, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  def confirm_change(reason)
    fill_in 'Reason for the change', with: reason
    check 'I reviewed the impact and confirm this role status change.'
    click_button 'Confirm status change'
    expect(page).to have_current_path(system_role_path(role))
    expect(page).to have_css('.swal2-popup')
    expect(page).to have_no_css('.swal2-popup', wait: 8)
  end

  scenario 'reviews deactivation with impact, reason and history on mobile' do
    create(:user_role, system_role: role)
    page.driver.browser.manage.window.resize_to(390, 844)
    visit system_role_path(role)
    click_button 'Review change'
    expect(page).to have_text('Users without another active role')
    expect(page).to have_text('This role will stop authorizing operations on the next request.')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
    confirm_change('Seasonal operation ended')
    expect(role.reload).to be_inactive
    expect(page).to have_text('Seasonal operation ended')
    expect(page).to have_link('Archive role')
  end

  scenario 'archives separately and restores without reactivating permissions' do
    visit status_review_system_role_path(role, target: 'inactive')
    confirm_change('Retiring this role')
    click_link 'Archive role'
    confirm_change('No current assignments remain')
    expect(role.reload).to be_deprecated
    expect(page).to have_no_button('Save permissions')
    click_link 'Restore as inactive'
    expect(page).to have_text('The role will return as inactive.')
    confirm_change('Review configuration for reuse')
    expect(role.reload).to be_inactive
    expect(role.status_events.count).to eq(3)
  end

  scenario 'blocks archiving when assignments remain' do
    create(:user_role, system_role: role)
    visit status_review_system_role_path(role, target: 'inactive')
    confirm_change('Suspend access temporarily')
    click_link 'Archive role'
    expect(page).to have_text('Revoke or reassign all current assignments')
    expect(page).to have_no_button('Confirm status change')
  end
end
