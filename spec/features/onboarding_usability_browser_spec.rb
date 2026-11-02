# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding screen', type: :feature, js: true do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization, :with_settings) }
  let!(:branch) { create(:branch, organization:) }

  before do
    create(:organization_membership, organization:, user:)
    role = create(:system_role, :system, code: 'administrator')
    create(:user_role, user:, system_role: role)
    sign_in user
    visit admin_onboarding_path(step: 1)
  end

  after { page.driver.browser.manage.window.resize_to(1400, 900) }

  def resize_viewport(width, height)
    offsets = page.evaluate_script('[outerWidth - innerWidth, outerHeight - innerHeight]')
    page.driver.browser.manage.window.resize_to(width + offsets[0], height + offsets[1])
  end

  scenario 'validates inline and keeps edited data when leaving is cancelled' do
    fill_in 'organization_name', with: ''
    click_button 'Save and continue'
    expect(page).to have_css('#organization_name:focus[aria-invalid="true"]')
    expect(page).to have_css('#organization_name_error', text: 'Company name')
    fill_in 'organization_name', with: 'Unsaved business'
    expect(page).to have_no_css('#organization_name_error', visible: true)
    find('.onboarding-desktop-steps a[href$="step=2"]').click
    expect(page).to have_css('.swal2-popup', text: 'You have unsaved changes')
    click_button 'Keep editing'
    expect(find('#organization_name').value).to eq('Unsaved business')
    find('.onboarding-desktop-steps a[href$="step=2"]').click
    click_button 'Discard and leave'
    expect(page).to have_css('#branch_name')
  end

  scenario 'keeps enhanced selects and focuses the first error after a real 422' do
    page.execute_script(<<~JS)
      const form = document.getElementById('onboarding-form')
      form.querySelector('#organization_name').value = ''
      form.submit()
    JS
    expect(page).to have_css('#organization_name_error', text: 'Company name')
    expect(page).to have_css('#organization_name:focus[aria-invalid="true"]')
    expect(page).to have_css('.onboarding-page [data-controller="delta-select"] button[aria-haspopup]', count: 3)
    expect(page).to have_css('.swal2-toast.swal2-icon-error', text: 'Could not save')
    errors = page.driver.browser.logs.get(:browser).map(&:message).join
    expect(errors).not_to include('Unknown icon', 'Translation missing')
  end

  scenario 'offers register creation without adding duplicates' do
    visit admin_onboarding_path(step: 3)
    fill_in 'recovery_name', with: 'Main register'
    expect do
      click_button 'Create first register'
      expect(page).to have_field('terminal_names_0_name', with: 'Main register')
    end.to change { branch.terminals.count }.by(1)
    expect(page).to have_field('terminal_names_0_name', with: 'Main register')
    expect(page).to have_no_button('Create first register')
  end

  scenario 'places the actual step in the first mobile screen and avoids horizontal overflow' do
    resize_viewport(320, 740)
    visit admin_onboarding_path(step: 1)
    expect(page).to have_css('.onboarding-mobile-steps', visible: true)
    expect(page).to have_no_css('.onboarding-desktop-steps', visible: true)
    dimensions = page.evaluate_script(
      '[innerWidth, innerHeight, document.getElementById("organization_name").getBoundingClientRect().bottom]'
    )
    expect(page.evaluate_script(<<~JS)).to be(true), "Viewport and field bottom: #{dimensions}"
      (() => {
        const title = document.getElementById('onboarding-step-title').getBoundingClientRect()
        const firstField = document.getElementById('organization_name').getBoundingClientRect()
        return title.top < innerHeight && firstField.bottom <= innerHeight &&
          document.documentElement.scrollWidth <= innerWidth
      })()
    JS
  end

  scenario 'preserves entered values and allows retrying after a network failure' do
    fill_in 'organization_name', with: 'Network business'
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      window.fetch = (input, options) => {
        const url = typeof input === 'string' ? input : input.url || String(input)
        return url.includes('/admin/onboarding') ? Promise.reject(new TypeError('Offline test')) : original(input, options)
      }
    JS
    click_button 'Save and continue'
    expect(page).to have_css('.swal2-toast.swal2-icon-error', text: 'We could not confirm the save')
    expect(page).to have_button('Save and continue', disabled: false)
    expect(find('#organization_name').value).to eq('Network business')
  end
  scenario 'creates the responsible person profile inside onboarding' do
    visit admin_onboarding_path(step: 5)
    fill_in 'recovery_first_name', with: 'Ana'
    fill_in 'recovery_last_name', with: 'Audit'
    expect do
      click_button 'Save my profile'
      expect(page).to have_no_css('#onboarding-team')
    end.to change { organization.employees.active.count }.by(1)
    find('.onboarding-card summary', text: 'Team').click
    expect(page).to have_content(user.email)
  end

  scenario 'adapts required address fields to the selected country' do
    create(:country, name: 'Hong Kong', iso_alpha2: 'HK', iso_alpha3: 'HKG', iso_numeric: '344')
    visit admin_onboarding_path(step: 2)
    expect(find('#branch_address_attributes_postal_code')['required']).to eq('true')
    find('[data-field-key="country_id"] button[aria-haspopup]').click
    find('[role="option"]', text: 'Hong Kong', exact_text: true).click
    expect(find('#branch_address_attributes_postal_code')['required']).to eq('false')
    expect(find('#branch_address_attributes_neighborhood')['required']).to eq('false')
    expect(find('#branch_address_attributes_city')['required']).to eq('true')
  end

  scenario 'preserves the form when the server is temporarily unavailable' do
    fill_in 'organization_name', with: 'Retry business'
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      window.fetch = (input, options) => {
        const url = typeof input === 'string' ? input : input.url || String(input)
        return url.includes('/admin/onboarding') ? Promise.resolve(new Response('Unavailable', { status: 503 })) : original(input, options)
      }
    JS
    click_button 'Save and continue'
    expect(page).to have_css('.swal2-toast.swal2-icon-error', text: 'Could not save right now')
    expect(page).to have_button('Save and continue', disabled: false)
    expect(find('#organization_name').value).to eq('Retry business')
  end

  scenario 'keeps the onboarding readable in all languages at mobile and tablet widths' do
    widths = [320, 768]
    %w[en es ko].each do |locale|
      language = Language.find_by(code: locale) || create(:language, code: locale, name: locale)
      user.update!(language:)
      widths.each do |width|
        resize_viewport(width, 740)
        visit admin_onboarding_path(step: 1)
        expect(find('html')['lang']).to eq(locale)
        expect(page).to have_css('#onboarding-title', text: I18n.t('admin.onboarding_ui.title', locale:))
        expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
      end
    end
  end
end
