# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication audit corrections', type: :feature, js: true do
  before do
    create(:language, :english)
    create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    create(:language, code: 'ko', name: '한국어', flag_iso: 'kr')
    create(:currency, code: 'MXN')
    visit new_user_session_path
  end

  after { page.driver.browser.manage.window.resize_to(1400, 900) }

  def next_step
    find('[data-registration-wizard-target="next"]').click
  end

  def visit_environment(type = 'migration')
    visit new_user_registration_path
    find("[data-setup-type='#{type}']").click
    next_step
    fill_in 'first-name', with: 'Ana'
    fill_in 'last-name', with: 'Audit'
    fill_in 'user_email', with: 'audit@example.invalid'
    fill_in 'user_password', with: 'not-a-real-password'
    fill_in 'user_password_confirmation', with: 'not-a-real-password'
    next_step
    fill_in 'company-name', with: 'Audit Shop'
    fill_in 'tax-id', with: 'XAXX010101000'
    next_step
    find('#business-sector').click
    find('[data-dropdown-value="grocery"]').click
  end

  def select_trigger(id)
    find("##{id}", visible: :all).find(:xpath, '..').find('button[aria-haspopup="listbox"]')
  end

  def choose_native(id, text)
    select_trigger(id).click
    find('[role="listbox"]:not([hidden]) [role="option"]', text:, exact_text: true).click
  end

  scenario 'clears corrected migration errors and connects feedback to the visible control' do
    visit_environment
    next_step

    trigger = select_trigger('migration-volume')
    expect(trigger['aria-invalid']).to eq('true')
    expect(trigger['aria-describedby']).to eq('registration-error-migration-volume')
    expect(find('#migration-volume', visible: :all)['aria-hidden']).to eq('true')
    focused = page.evaluate_script(
      'document.activeElement === document.querySelector("#migration-volume").nextElementSibling'
    )
    expect(focused).to be(true)

    choose_native('migration-volume', '500 to 5,000 products')
    expect(page).to have_no_css('#registration-error-migration-volume')
    expect(select_trigger('migration-volume')['aria-invalid']).to eq('false')
    expect(select_trigger('migration-volume')['aria-describedby']).to be_nil
    expect(page).to have_css('#registration-error-migration-priority')

    select_trigger('migration-priority').send_keys(:arrow_down)
    expect(page).to have_css('[role="listbox"]:not([hidden])')
    find('[role="option"]', text: 'All of the above', exact_text: true).send_keys(:enter)
    expect(page).to have_no_css('#registration-error-migration-priority')
    select_trigger('timezone-select').send_keys(:arrow_up)
    expect(page).to have_css('[role="listbox"]:not([hidden])')
    page.driver.browser.action.send_keys(:escape).perform
    expect(select_trigger('timezone-select')['aria-expanded']).to eq('false')
  end

  scenario 'shows all migration choices and refreshes the summary after editing' do
    visit_environment
    choose_native('migration-volume', '500 to 5,000 products')
    choose_native('migration-priority', 'All of the above')
    choose_native('timezone-select', 'America/Tijuana')
    next_step

    expect(page).to have_css('[data-summary-key="setup"]', text: 'Migration')
    expect(page).to have_css('[data-summary-key="timezone"]', text: 'America/Tijuana')
    expect(page).to have_css('[data-summary-key="volume"]', text: '500 to 5,000 products')
    expect(page).to have_css('[data-summary-key="priority"]', text: 'All of the above')
    find('[data-registration-wizard-target="back"]').click
    choose_native('migration-volume', 'Fewer than 500 products')
    next_step
    expect(page).to have_css('[data-summary-key="volume"]', text: 'Fewer than 500 products')
    expect(find('#terms')).not_to be_checked
    next_step
    expect(page).to have_css('[data-registration-field-error]', text: 'Terms and Privacy Policy must be accepted')
  end

  scenario 'omits migration preferences when configuring a new system' do
    visit_environment('new')
    next_step
    expect(page).to have_css('[data-summary-key="setup"]', text: 'New system')
    expect(page).to have_css('[data-summary-key="name"]', text: 'Ana Audit')
    expect(page).to have_no_css('[data-summary-migration]', visible: true)
  end

  scenario 'names the administrator field before each validation message' do
    visit new_user_registration_path
    find('[data-setup-type="new"]').click
    next_step
    next_step

    expect(page).to have_css('#registration-error-first-name', text: "First Name can't be blank.")
    expect(page).to have_css('#registration-error-last-name', text: "Last Name can't be blank.")
    expect(page).to have_css('#registration-error-user-email', text: "Email address can't be blank")
    expect(page).to have_css('#registration-error-user-password', text: "Password can't be blank")
    fill_in 'first-name', with: 'A'
    fill_in 'user_email', with: 'invalid-address'
    fill_in 'user_password', with: '123'
    next_step

    expect(page).to have_css('#registration-error-first-name', text: 'First Name must contain at least 2 characters.')
    expect(page).to have_css('#registration-error-user-email', text: 'Email address must be a valid email address')
    expect(page).to have_css('#registration-error-user-password', text: 'Password must contain at least 6 characters.')
  end

  scenario 'keeps branding and current-step text readable at supported widths and languages' do
    widths = [320, 359, 390, 768, 1440]
    %w[en es ko].each do |locale|
      page.driver.browser.manage.add_cookie(name: 'terminal_language', value: locale)
      widths.each do |width|
        page.driver.browser.manage.window.resize_to(width, 900)
        visit new_user_registration_path
        expect(find('html')['lang']).to eq(locale)
        expect(page).to have_css('main h1')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
        next if width >= 1024

        expect(page.evaluate_script(<<~JS)).to be(true)
          (() => {
            const brand = document.querySelector('[data-registration-header] [aria-label="Delta POS"]').getBoundingClientRect();
            const controls = document.querySelector('[data-registration-controls]').getBoundingClientRect();
            return brand.bottom <= controls.top || brand.right <= controls.left;
          })()
        JS
        next if width >= 640

        expect(page).to have_css('[data-mobile-step-status]', text: '1 / 5')
        expect(page.evaluate_script(<<~JS)).to be(true)
          Array.from(document.querySelectorAll('[data-step-label]')).every(e => e.getBoundingClientRect().width <= 1);
        JS
      end
    end
  end

  scenario 'maintains AA contrast for actions and links in every terminal theme' do
    themes = Theme.all
    themes.each do |theme|
      find('[data-theme-toggle]').click
      find("[data-theme='#{theme[:id]}']").click
      contrast = page.evaluate_script(<<~JS)
        (() => {
          const linear = c => (c /= 255) <= .04045 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4;
          const luminance = color => color.match(/[0-9.]+/g).slice(0, 3).map(Number).map(linear)
            .reduce((s, c, i) => s + c * [.2126, .7152, .0722][i], 0);
          const ratio = (a, b) => (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
          const button = getComputedStyle(document.querySelector('[data-terminal-target="loginSubmit"]'));
          const link = getComputedStyle(document.querySelector('a.theme-text'));
          return Math.min(ratio(luminance(button.color), luminance(button.backgroundColor)), ratio(luminance(link.color), 1));
        })()
      JS
      expect(contrast).to be >= 4.5
    end
  end
end
