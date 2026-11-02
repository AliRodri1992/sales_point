# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Demo request wizard focus', type: :feature, js: true do
  before do
    create(:language, :english)
    visit new_demo_request_path
    page.driver.browser.manage.add_cookie(name: 'terminal_language', value: 'en')
    visit new_demo_request_path
  end

  scenario 'focuses the first invalid field without raising a JavaScript action error' do
    click_button I18n.t('demo_requests.new.continue')
    expect(page).to have_css('#demo_request_name[aria-invalid="true"]:focus')
    expect(page).to have_css('#demo_request_name_error', visible: true)
    errors = page.driver.browser.logs.get(:browser).map(&:message).join
    expect(errors).not_to include('focusFirstInvalid is not a function')
  end

  scenario 'announces the next step, focuses an enhanced invalid select and preserves contact data on return' do
    fill_in 'demo_request_name', with: 'Demo Test'
    fill_in 'demo_request_email', with: 'demo@example.invalid'
    fill_in 'demo_request_phone', with: '2221234567'
    expect(page).to have_css('#demo_request_phone[data-valid="true"]')
    click_button I18n.t('demo_requests.new.continue')
    expect(page).to have_css('[data-step="2"] h3:focus')

    # Terms remain unchecked: this exercises local validation without submitting a request.
    click_button I18n.t('demo_requests.new.submit')
    expect(page).to have_css('#demo_business_type[aria-invalid="true"]', visible: :all)
    expect(page).to have_css('.delta-select-container button[aria-haspopup="listbox"]:focus')
    click_button I18n.t('demo_requests.new.back_step')
    expect(page).to have_css('[data-step="1"] h3:focus')
    expect(find('#demo_request_email').value).to eq('demo@example.invalid')
  end

  scenario 'focuses the success notice when the form is no longer present' do
    allow_any_instance_of(DemoRequestsController).to receive(:new).and_wrap_original do |action|
      action.receiver.flash.now[:notice] = I18n.t('demo_requests.create.success')
      action.call
    end
    visit new_demo_request_path

    expect(page).to have_css('[data-demo-request-wizard-target="success"]:focus')
    expect(page).to have_no_css('form[action="/demo_requests"]')
    errors = page.driver.browser.logs.get(:browser).map(&:message).join
    expect(errors).not_to include('Missing target element "progress"')
  end
end
