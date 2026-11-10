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

  scenario 'creates and validates an inactive language in a centered dialog' do
    visit admin_languages_path
    click_link 'New language'

    expect(page).to have_css('#language_modal[aria-hidden="false"] .languages-modal-panel', wait: 10)
    expect(page).to have_css('#language_modal [role="dialog"][aria-modal="true"]')

    within('#language_modal') do
      fill_in 'language_name', with: 'French draft'
      fill_in 'language_code', with: 'fr'
      fill_in 'language_flag_iso', with: 'fr'
      click_button 'Create language'
    end

    expect(page).to have_css('#language_modal #language_code_error', wait: 10)
    expect(page).to have_css('#language_modal[aria-hidden="false"]')

    within('#language_modal') do
      find('.catalog-field [data-controller="delta-select"] button[aria-haspopup="listbox"]').click
      find('[role="option"]', text: 'Inactive').click
      click_button 'Create language'
    end

    expect(page).to have_no_css('#language_modal[aria-hidden="false"]', wait: 10)
    expect(page).to have_css('.languages-name', text: 'French draft', wait: 10)
    expect(page).to have_current_path(admin_languages_path)
  end

  scenario 'places New language just above filters and preserves the wider dialog' do
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit admin_languages_path

    expect(page).to have_css('.languages-actions-bar .languages-new-button', visible: true)
    expect(page).to have_no_css('.languages-filters .languages-new-button')
    expect(page).to have_no_css('.languages-page-header .languages-new-button')
    positioning = page.evaluate_script(<<~JS)
      (() => {
        const button = document.querySelector('.languages-actions-bar .languages-new-button')
        const filters = document.querySelector('.languages-filters')
        return {
          gap: filters.getBoundingClientRect().top - button.getBoundingClientRect().bottom,
          rightGap: Math.abs(button.getBoundingClientRect().right - filters.getBoundingClientRect().right)
        }
      })()
    JS
    expect(positioning.fetch('gap')).to be_between(0, 16)
    expect(positioning.fetch('rightGap')).to be <= 2
    within('.languages-actions-bar') { click_link 'New language' }

    expect(page).to have_css('#language_modal[aria-hidden="false"] .languages-modal-panel', wait: 10)
    dimensions = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('.languages-modal-panel')
        const fields = panel.querySelector('.languages-editor__fields')
        return {
          width: Math.round(panel.getBoundingClientRect().width),
          columns: getComputedStyle(fields).gridTemplateColumns.trim().split(/\\s+/).length
        }
      })()
    JS
    expect(dimensions.fetch('width')).to be_between(620, 710)
    expect(dimensions.fetch('columns')).to eq(2)

    page.driver.browser.manage.window.resize_to(390, 844)
    compact = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('.languages-modal-panel')
        const rect = panel.getBoundingClientRect()
        return {
          columns: getComputedStyle(panel.querySelector('.languages-editor__fields')).gridTemplateColumns
            .trim().split(/\\s+/).length,
          left: rect.left,
          right: rect.right,
          viewportWidth: window.innerWidth
        }
      })()
    JS
    expect(compact.fetch('columns')).to eq(1)
    expect(compact.fetch('left')).to be >= 0
    expect(compact.fetch('right')).to be <= compact.fetch('viewportWidth')
  ensure
    page.driver.browser.manage.window.resize_to(1280, 900)
  end

  scenario 'edits an existing language without navigating away' do
    create(:language, name: 'French draft', code: 'fr', flag_iso: 'fr', status: 'inactive')
    visit admin_languages_path

    within('.languages-desktop-table tbody tr', text: 'French draft') do
      find('a[data-turbo-frame="language_modal"]', match: :first).click
    end

    expect(page).to have_css('#language_modal[aria-hidden="false"]', wait: 10)
    within('#language_modal') do
      expect(page).to have_css('#language_code[readonly]')
      fill_in 'language_name', with: 'French revised'
      click_button 'Update language'
    end

    expect(page).to have_no_css('#language_modal[aria-hidden="false"]', wait: 10)
    expect(page).to have_css('.languages-name', text: 'French revised', wait: 10)
    expect(page).to have_current_path(admin_languages_path)
  end

  scenario 'closes the form using Escape without leaving the listing' do
    visit admin_languages_path
    click_link 'New language'
    expect(page).to have_css('#language_modal[aria-hidden="false"]', wait: 10)

    find('#language_modal input#language_name').send_keys(:escape)

    expect(page).to have_no_css('#language_modal[aria-hidden="false"]', wait: 10)
    expect(page).to have_current_path(admin_languages_path)
  end

  scenario 'protects persisted identifiers and uses the Delta status dropdown' do
    visit edit_admin_language_path(administrator.language)

    expect(page).to have_css('#language_code[readonly]')
    expect(page).to have_css('[data-controller="delta-select"]')
    expect(page).to have_css('#language_status', visible: :all)
  end
end
