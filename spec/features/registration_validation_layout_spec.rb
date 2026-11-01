# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Registration validation layout', type: :feature, js: true do
  before do
    create(:language, :english)
    create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    create(:currency, code: 'MXN')
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  def form_height
    page.evaluate_script('document.querySelector("[data-registration-form-card] form").getBoundingClientRect().height')
  end

  def aside_top
    page.evaluate_script('document.querySelector(".registration-page aside").getBoundingClientRect().top')
  end

  def visit_administrator_step
    visit new_user_registration_path
    find('[data-setup-type="new"]').click
    find('[data-registration-wizard-target="next"]').click
    expect(page).to have_css('section[data-step="2"]:not(.hidden)')
  end

  scenario 'does not resize the form or move the promotional panel when client errors appear' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit_administrator_step

    height_before = form_height
    aside_top_before = aside_top
    find('[data-registration-wizard-target="next"]').click

    expect(page).to have_css('[data-registration-field-error]', minimum: 3)
    expect(form_height).to be_within(1).of(height_before)
    aside_top_after = aside_top
    expect(aside_top_after).to be_within(1).of(aside_top_before)
  end

  scenario 'keeps a stable form height and fits narrow mobile screens after validation' do
    page.driver.browser.manage.window.resize_to(375, 740)
    visit_administrator_step

    height_before = form_height
    find('[data-registration-wizard-target="next"]').click

    expect(page).to have_css('[data-registration-field-error]', minimum: 3)
    expect(form_height).to be_within(1).of(height_before)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

    fill_in 'first-name', with: 'Ana'
    expect(find('#first-name')['aria-invalid']).to be_nil
    expect(page).to have_css('[data-registration-field-error]', minimum: 1)
    expect(form_height).to be_within(1).of(height_before)
  end
end
