# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'General settings page', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:admin) { create(:user, :english) }

  before do
    create(:organization_membership, user: admin, organization:)
    create(:user_role, user: admin,
                       system_role: create(:system_role, :system, code: 'administrator'))
    create(:organization_setting, organization:, default_table_page_size: 10)
    Warden.test_mode!
    login_as(admin, scope: :user)
  end

  after do
    page.execute_script("document.documentElement.style.zoom = ''") if page.driver.browser
    page.current_window.resize_to(1440, 900)
    Warden.test_reset!
  end

  scenario 'updates the illustrative preview before save and persists the selection' do
    visit admin_general_settings_path
    wrapper = find('select[name="organization_setting[default_table_page_size]"]', visible: :all).find(:xpath, '..')
    wrapper.find('button[aria-haspopup="listbox"]').click
    wrapper.find('[role="option"]', text: '25 records').click

    expect(page).to have_css('[data-general-settings-preview-target="summary"]',
                             text: 'Showing 25 records per page by default.')
    expect(page).to have_css('input[name="expected_settings_updated_at"]', visible: :all)
    expect(page).to have_css('[data-general-settings-preview-target="dirty"]', text: 'Unsaved changes')
    expect(page).to have_button('Save preference', disabled: false)

    click_button 'Save preference'

    expect(page).to have_css('[data-general-settings-preview-target="summary"]',
                             text: 'Showing 25 records per page by default.')
    expect(organization.organization_settings.active_records.first.default_table_page_size).to eq(25)
  end

  scenario 'does not offer a save action until the user changes the original value' do
    visit admin_general_settings_path

    expect(page).to have_button('Save preference', disabled: true)
    expect(page).to have_css('[data-general-settings-preview-target="dirty"]', text: 'No pending changes')

    dropdown = find('select[name="organization_setting[default_table_page_size]"]', visible: :all).find(:xpath, '..')
    dropdown.find('button[aria-haspopup="listbox"]').click
    dropdown.find('[role="option"]', text: '25 records').click
    expect(page).to have_button('Save preference', disabled: false)

    dropdown.find('button[aria-haspopup="listbox"]').click
    dropdown.find('[role="option"]', text: '10 records').click
    expect(page).to have_button('Save preference', disabled: true)
    expect(page).to have_css('[data-general-settings-preview-target="dirty"]', text: 'No pending changes')
  end

  scenario 'keeps the form within mobile and desktop viewports with an accessible select' do
    [320, 390, 768, 1440].each do |width|
      page.current_window.resize_to(width, 900)
      visit admin_general_settings_path
      expect(page).to have_css('button[aria-haspopup="listbox"][aria-required="true"]')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
    end

    # A 512px CSS viewport checks reflow equivalent to 1024px at 200% browser zoom.
    # CSS style.zoom is not browser zoom and can distort window.innerWidth in Chrome.
    page.current_window.resize_to(512, 900)
    visit admin_general_settings_path
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)
  end
end
