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

  scenario 'shows field errors in flow without moving the promotional panel' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit_administrator_step

    height_before = form_height
    aside_top_before = aside_top
    find('[data-registration-wizard-target="next"]').click

    expect(page).to have_css('[data-registration-field-error]', minimum: 3)
    expect(form_height).to be > height_before
    expect(aside_top).to be_within(1).of(aside_top_before)
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const first = document.querySelector("#first-name").closest("[data-field]");
        const next = document.querySelector("#last-name").getBoundingClientRect();
        return first.querySelector("[data-registration-field-error]").getBoundingClientRect().bottom <= next.top;
      })()
    JS
  end

  scenario 'keeps the layout within narrow mobile screens and clears corrected errors' do
    page.driver.browser.manage.window.resize_to(375, 740)
    visit_administrator_step

    height_before = form_height
    find('[data-registration-wizard-target="next"]').click

    expect(page).to have_css('[data-registration-field-error]', minimum: 3)
    expect(form_height).to be > height_before
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

    height_with_errors = form_height
    fill_in 'first-name', with: 'Ana'
    expect(find('#first-name')['aria-invalid']).to be_nil
    expect(page).to have_css('[data-registration-field-error]', minimum: 1)
    expect(form_height).to be < height_with_errors
  end

  scenario 'highlights exactly one implementation option without changing either card height' do
    visit new_user_registration_path

    new_card = find('[data-setup-type="new"]')
    migration_card = find('[data-setup-type="migration"]')
    initial_heights = page.evaluate_script(
      'Array.from(document.querySelectorAll("[data-registration-wizard-target=setupCard]")).map(e => e.offsetHeight)'
    )

    new_card.click
    expect(new_card['aria-pressed']).to eq('true')
    expect(new_card[:class]).to include('border-emerald-600')
    expect(new_card).to have_css('[data-setup-check]:not(.opacity-0)')
    expect(new_card).to have_css('[data-setup-selected-label]:not(.invisible)')
    expect(migration_card['aria-pressed']).to eq('false')

    migration_card.click
    expect(migration_card['aria-pressed']).to eq('true')
    expect(new_card['aria-pressed']).to eq('false')
    expect(new_card).to have_css('[data-setup-check].opacity-0', visible: :all)
    expect(
      page.evaluate_script(
        'Array.from(document.querySelectorAll("[data-registration-wizard-target=setupCard]")).map(e => e.offsetHeight)'
      )
    ).to eq(initial_heights)
  end

  scenario 'keeps fields close together when there are no validation errors' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit_administrator_step

    gap = page.evaluate_script(<<~JS)
      (() => {
        const first = document.querySelector("#first-name").closest("[data-field]");
        const next = document.querySelector("#last-name").closest("[data-field]");
        return next.getBoundingClientRect().top - first.getBoundingClientRect().bottom;
      })()
    JS

    expect(gap).to be_between(8, 16)
    expect(find('#first-name').find(:xpath, './ancestor::*[@data-field][1]')[:class]).not_to include('pb-')
    expect(page).to have_no_css('[data-registration-field-error]')
  end
end
