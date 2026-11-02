# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Demo request usability', type: :feature, js: true do
  before do
    create(:language, :english)
    create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    create(:language, code: 'ko', name: '한국어', flag_iso: 'kr')
    visit new_demo_request_path
    page.driver.browser.manage.add_cookie(name: 'terminal_language', value: 'en')
    visit new_demo_request_path
  end

  after { page.driver.browser.manage.window.resize_to(1400, 900) }

  scenario 'treats Enter in contact fields as Continue without premature business errors' do
    fill_contact
    find('#demo_request_phone').send_keys(:enter)
    expect(page).to have_css('[data-step="2"] .demo-step-title:focus')
    expect(page).to have_no_css('[data-step="2"] .demo-field-error', visible: true)
    expect(page).to have_no_css('.swal2-toast')
  end

  scenario 'matches model length constraints and clears the field message after correction' do
    fill_contact(name: 'A')
    find('[data-action="demo-request-wizard#next"]').click
    expect(page).to have_css('#demo_request_name_error', text: 'Full name must have at least 2 characters.')
    fill_in 'demo_request_name', with: 'Audit User'
    expect(page).to have_no_css('#demo_request_name_error', visible: true)
    expect(page).to have_css('#demo_request_name[aria-invalid="false"]')
    find('[data-action="demo-request-wizard#next"]').click
    fill_in 'demo_request_company', with: 'A'
    find('input[type="submit"]').click
    expect(page).to have_css('#demo_request_company_error', text: 'Company must have at least 2 characters.')
    fill_in 'demo_request_company', with: 'Audit Company'
    expect(page).to have_no_css('#demo_request_company_error', visible: true)
    expect(find('#demo_request_company')['maxlength']).to eq('150')
  end

  scenario 'keeps country, values, theme and active step when switching language' do
    find('.iti__selected-country').click
    find('[role="option"]', text: 'United States (+1)', exact_text: true).click
    fill_contact(phone: '4155552671')
    find('[data-action="demo-request-wizard#next"]').click
    choose_business
    fill_in 'demo_request_company', with: 'Audit Company'
    find('[data-demo-request-wizard-target="themeButton"]').click
    find('[data-theme="ruby"]').click
    color = primary_color
    find('#languageSelectorButton').click
    find('#language-selector-menu button[data-language="es"]').click
    expect(page).to have_css('html[lang="es"]')
    expect(page).to have_css('[data-step="2"]', visible: true)
    expect(find('#demo_request_company').value).to eq('Audit Company')
    expect(find('#demo_business_type', visible: :all).value).to eq('grocery')
    expect(primary_color).to eq(color)
    find('[data-action="demo-request-wizard#back"]').click
    expect(find('#demo_request_name').value).to eq('Audit User')
    expect(find('#demo_request_email').value).to eq('audit@example.invalid')
    expect(page).to have_css('#demo_request_phone[data-country-code="US"][data-valid="true"]')
    expect(page).to have_css('.iti__selected-country[aria-label*="Estados Unidos"]')
  end

  scenario 'provides named theme choices with accessible action contrast and Escape focus' do
    DemoRequests::FormComponent::THEMES.each do |name, _start, _finish|
      find('[data-demo-request-wizard-target="themeButton"]').click
      find("[data-theme='#{name}']").click
      expect(page.evaluate_script(<<~'JS')).to be >= 4.5
        (() => {
          const background = getComputedStyle(document.querySelector('[data-action="demo-request-wizard#next"]')).backgroundImage
          const colors = [...background.matchAll(/rgb\((\d+), (\d+), (\d+)\)/g)]
          if (colors.length !== 2) return 0
          return Math.min(...colors.map(match => {
            const channels = match.slice(1).map(Number).map(value => value / 255)
              .map(value => value <= 0.04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4)
            return 1.05 / (channels[0] * .2126 + channels[1] * .7152 + channels[2] * .0722 + .05)
          }))
        })()
      JS
    end
    find('[data-demo-request-wizard-target="themeButton"]').click
    expect(page).to have_css('[data-theme="slate"][aria-pressed="true"]:focus')
    find('[data-theme="slate"]').send_keys(:escape)
    expect(page).to have_css('[data-demo-request-wizard-target="themeButton"][aria-expanded="false"]:focus')
  end

  scenario 'keeps controls separate and lets the user reach the form footer at audited sizes' do
    fill_contact
    find('[data-action="demo-request-wizard#next"]').click
    find('input[type="submit"]').click
    [[320, 740], [1440, 500], [768, 600]].each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)
      expect(page.evaluate_script(<<~JS)).to be(true), "Layout at #{width} x #{height}"
        (() => {
          const toolbar = document.querySelector('.demo-toolbar').getBoundingClientRect()
          const progress = document.querySelector('nav[aria-label]').getBoundingClientRect()
          const controls = [...document.querySelectorAll('.demo-primary-button,.demo-secondary-button')]
            .filter(element => element.getBoundingClientRect().width > 0)
          return progress.top >= toolbar.bottom && document.documentElement.scrollWidth <= innerWidth &&
            controls.every(element => element.getBoundingClientRect().height >= 44)
        })()
      JS
      find('a[href="/"]', match: :first).send_keys(:tab)
      expect(page).to have_css('[data-step="2"]', visible: true)
    end
  end

  scenario 'opens the earliest invalid step and associates the complete server message with its input' do
    page.execute_script(<<~JS)
      const form = document.querySelector('form[action="/demo_requests"]')
      form.querySelector('#demo_request_name').value = 'A'
      form.querySelector('#demo_request_email').value = 'audit@example.invalid'
      form.querySelector('#demo_request_phone').value = '+525512345678'
      form.querySelector('#demo_business_type').value = 'grocery'
      form.querySelector('#demo_request_company').value = 'A'
      form.querySelector('#demo_request_branches').value = '1'
      form.submit()
    JS
    expect(page).to have_css('#demo_request_name_error', text: 'Full name')
    expect(page).to have_css('[data-step="1"] #demo_request_name:focus')
    expect(find('#demo_request_company_error', visible: :all).text(:all)).to start_with('Company ')
    expect(find('#demo_request_company', visible: :all)['aria-describedby']).to eq('demo_request_company_error')
    expect(page).to have_no_css('.demo-field-error p', visible: :all)
  end

  scenario 'preserves the form and displays one persistent error after a failed connection' do
    ready_to_submit
    page.execute_script(<<~JS)
      const originalFetch = window.fetch.bind(window)
      window.fetch = (input, options) => {
        const url = typeof input === 'string' ? input : input.url || String(input)
        return url.includes('/demo_requests') ? Promise.reject(new TypeError('Simulated connection loss')) : originalFetch(input, options)
      }
    JS
    expect do
      find('input[type="submit"]').click
      expect(page).to have_css('.swal2-toast.swal2-icon-error',
                               text: I18n.t('demo_requests.form.network_error'), count: 1)
      expect(page).to have_css('input[type="submit"]:not([disabled])')
    end.not_to change(DemoRequest, :count)
    expect(find('#demo_request_company').value).to eq('Audit Company')
    find('.swal2-close').click
    expect(page).to have_no_css('.swal2-toast')
    expect(page).to have_css('input[type="submit"]:focus')
  end

  scenario 'handles server failure without replacing the completed form' do
    ready_to_submit
    page.execute_script(<<~JS)
      const originalFetch = window.fetch.bind(window)
      window.fetch = (input, options) => {
        const url = typeof input === 'string' ? input : input.url || String(input)
        return url.includes('/demo_requests') ? Promise.resolve(new Response('Unavailable', { status: 503 })) : originalFetch(input, options)
      }
    JS
    find('input[type="submit"]').click
    expect(page).to have_css('.swal2-toast.swal2-icon-error', text: I18n.t('demo_requests.form.server_error'))
    expect(page).to have_css('input[type="submit"]:not([disabled])')
    expect(find('#demo_request_company').value).to eq('Audit Company')
  end

  def primary_color
    page.evaluate_script("getComputedStyle(document.querySelector('main')).getPropertyValue('--demo-primary-start')")
  end

  def fill_contact(name: 'Audit User', phone: '2221234567')
    fill_in 'demo_request_name', with: name
    fill_in 'demo_request_email', with: 'audit@example.invalid'
    fill_in 'demo_request_phone', with: phone
    expect(page).to have_css('#demo_request_phone[data-valid="true"]')
  end

  def choose_business
    label = find('#demo_business_type option[value="grocery"]', visible: :all).text(:all)
    find('.delta-select-container button[aria-haspopup="listbox"]').click
    find('[role="option"]', text: label, exact_text: true).click
  end

  def ready_to_submit
    fill_contact
    find('[data-action="demo-request-wizard#next"]').click
    choose_business
    fill_in 'demo_request_company', with: 'Audit Company'
    # Test consent only; the fetch stub prevents any request from reaching the server.
    check 'demo_request_terms_accepted'
  end
end
