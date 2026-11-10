# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Languages administration quality', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, organization:, user: administrator)
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'shows a field-level error when an unsupported language is activated' do
    visit admin_languages_path
    click_link 'New language'

    fill_in 'language_name', with: 'Français'
    fill_in 'language_code', with: 'fr'
    fill_in 'language_flag_iso', with: 'fr'
    click_button 'Create language'

    expect(page).to have_css('#language_code_error', wait: 10)
    expect(page).to have_css('#language_code[aria-invalid="true"]')
    expect(page).to have_field('language_name', with: 'Français')
    expect(Language.find_by(code: 'fr')).to be_nil
  end

  scenario 'updates search and status automatically and clears filters' do
    create(:language, name: 'French draft', code: 'fr', flag_iso: 'fr', status: 'inactive')

    visit admin_languages_path
    expect(page).to have_css('.languages-filter-form[data-controller="languages-search"]')
    expect(page).to have_no_css('.languages-filter-form input[type="submit"]')

    fill_in 'search', with: 'French draft'
    expect(page).to have_css('.languages-filter-chip', text: 'Search: French draft', wait: 10)
    expect(page).to have_css('.languages-name', text: 'French draft')

    within('.languages-filter-status') do
      find('button[aria-haspopup="listbox"]').click
      find('[role="option"]', text: 'Inactive').click
    end

    expect(page).to have_css('.languages-filter-chip', text: 'Status: Inactive', wait: 10)
    click_link 'Clear filters'
    expect(page).to have_no_css('.languages-active-filters', wait: 10)
  end

  scenario 'uses readable language cards on narrow screens' do
    create(:language, name: 'French draft', code: 'fr', flag_iso: 'fr', status: 'inactive')
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_languages_path

    expect(page).to have_css('.languages-mobile-list', visible: true)
    expect(page).to have_css('.languages-mobile-list .languages-name', text: 'French draft')
    expect(page).to have_no_css('.languages-desktop-table', visible: true)
  ensure
    page.driver.browser.manage.window.resize_to(1280, 900)
  end

  scenario 'protects persisted identifiers and uses the Delta status dropdown' do
    visit edit_admin_language_path(administrator.language)

    expect(page).to have_css('#language_code[readonly]')
    expect(page).to have_css('[data-controller="delta-select"]')
    expect(page).to have_css('#language_status', visible: :all)
  end
end
