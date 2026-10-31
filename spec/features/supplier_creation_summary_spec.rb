# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier creation summary', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  def await_border_color(element, expected)
    Selenium::WebDriver::Wait.new(timeout: 4, interval: 0.05).until do
      page.evaluate_script('getComputedStyle(arguments[0]).borderTopColor', element) == expected
    end
  end

  scenario 'uses the available width and exposes section progress without a promotional panel' do
    visit new_admin_supplier_path

    expect(page).to have_css('[data-supplier-form-target="progress"]')
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-state]', count: 6, visible: :all)
    expect(page).to have_no_css('img[src*="supplier-delivery"]', visible: :all)
    expect(page).to have_css('form[data-controller="supplier-form"]')
    expect(page).to have_css('nav details[data-supplier-form-target="navigation"]')
    expect(page).to have_no_css('[data-supplier-form-target="activeLabel"]', visible: :all)
    expect(page).to have_css('nav details [data-supplier-form-target="tab"]', count: 6, visible: :all)
    expect(page).to have_no_css('nav .overflow-x-auto', visible: :all)
    expect(page).to have_no_css('nav[class*="sticky"]', visible: :all)
  end

  scenario 'lets editors switch sections from a compact menu without reloading' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier)

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('button[data-step-index="3"]').click

    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden) h2',
                             text: I18n.t('admin.suppliers.onboarding.steps.step_5'))
    expect(page).to have_no_css('[data-supplier-form-target="activeLabel"]', visible: :all)
    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden)', count: 1)
    expect(page).to have_no_css('details[data-supplier-form-target="navigation"][open]', visible: :all)
  end

  scenario 'shows the active heading only once when editing a supplier' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier)

    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden) h2',
                             text: I18n.t('admin.suppliers.onboarding.steps.step_1'), count: 1)
    expect(page).to have_no_css('[data-supplier-form-target="activeLabel"]', visible: :all)
    expect(page).to have_css('nav details[data-supplier-form-target="navigation"]')

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('button[data-step-index="1"]').click

    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden) h2',
                             text: I18n.t('admin.suppliers.onboarding.steps.step_2'), count: 1)
  end

  scenario 'closes section picker on Escape and restores keyboard focus' do
    visit new_admin_supplier_path
    navigation = find('details[data-supplier-form-target="navigation"]')
    summary = navigation.find('summary')
    summary.click
    expect(page).to have_css('details[data-supplier-form-target="navigation"][open]', visible: :all)

    summary.send_keys(:escape)

    expect(page).to have_no_css('details[data-supplier-form-target="navigation"][open]', visible: :all)
    expect(page.evaluate_script('document.activeElement.tagName')).to eq('SUMMARY')
  end

  scenario 'keeps the compact navigation inside the viewport on mobile' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_admin_supplier_path

    expect(page).to have_css('details[data-supplier-form-target="navigation"] > summary', visible: true)
    expect(page).to have_css('[data-supplier-form-target="position"]', visible: true)
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const nav = document.querySelector('nav[aria-label] details[data-supplier-form-target="navigation"]')
        const bounds = nav.getBoundingClientRect()
        return bounds.left >= 0 && bounds.right <= window.innerWidth
      })()
    JS
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  scenario 'marks invalid required fields with red borders and restores them after correction' do
    visit new_admin_supplier_path

    find('[data-supplier-form-target="next"]').click

    code = find('input[name="supplier[code]"]')
    expect(code['aria-invalid']).to eq('true')
    expect(code['class']).to include('input-field-error')
    expect(code['aria-invalid']).to eq('true')
    transition = page.evaluate_script('getComputedStyle(arguments[0]).transitionProperty', code)
    expect(transition).not_to include('border-color')
    await_border_color(code, 'rgb(225, 29, 72)')

    code.click
    await_border_color(code, 'rgb(225, 29, 72)')

    code.fill_in with: 'SUP-VALID-01'
    expect(code['aria-invalid']).not_to eq('true')
    expect(code['class']).not_to include('input-field-error')
    Selenium::WebDriver::Wait.new(timeout: 4, interval: 0.05).until do
      page.evaluate_script('getComputedStyle(arguments[0]).borderTopColor', code) != 'rgb(225, 29, 72)'
    end
  end

  scenario 'shows the same error styling on the visible custom select trigger' do
    visit new_admin_supplier_path

    page.execute_script(<<~JS)
      const form = document.querySelector('form[data-controller="supplier-form"]')
      window.Stimulus.getControllerForElementAndIdentifier(form, 'supplier-form').indexValue = 1
    JS

    find('[data-supplier-form-target="next"]').click
    select = find('select[name="supplier[person_type]"]', visible: :all)
    expect(select['aria-invalid']).to eq('true')
    trigger = find('[data-controller~="delta-select"] button[aria-haspopup="listbox"][aria-invalid="true"]',
                   visible: true, match: :first)
    await_border_color(trigger, 'rgb(225, 29, 72)')
  end

  scenario 'offers six real capture sections without a duplicate summary panel' do
    visit new_admin_supplier_path

    expect(page).to have_css('form[data-supplier-form-new-record-value="true"]', visible: :all)
    expect(page).to have_css('[data-supplier-form-target="step"]', count: 6, visible: :all)
    expect(page).to have_css('[data-supplier-form-target="tab"]', count: 6, visible: :all)
    expect(page).to have_css('[data-step-indicator]', count: 6, visible: :all)
    expect(page).to have_no_css('[data-supplier-form-target="summary"]', visible: :all)
    expect(page).to have_no_css('[data-step-index="6"]', visible: :all)
    expect(page).to have_css('input[name="supplier[code]"]', visible: :all)
    expect(page).to have_css('input[name$="[mobile_phone]"]', visible: :all)
    expect(page).to have_css('select[name="supplier[responsible_user_id]"]', visible: :all)
    expect(page).to have_css('textarea[name="supplier[notes]"]', visible: :all)
  end

  scenario 'opens the fiscal editing section directly and keeps save available' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier, return_to: 'fiscal')

    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden)', count: 1)
    expect(page).to have_css('[data-supplier-form-target="tab"][aria-current="location"][data-step-index="1"]',
                             visible: :all)
    expect(page).to have_css('[data-supplier-form-target="submit"]', visible: true)
  end

  scenario 'lets existing suppliers move between editing sections without onboarding validation' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier)

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('[data-supplier-form-target="tab"][data-step-index="1"]').click
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="1"][aria-current="location"]',
                             visible: :all)

    navigation.find('summary').click
    navigation.find('[data-supplier-form-target="tab"][data-step-index="3"]').click
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="3"][aria-current="location"]',
                             visible: :all)
    expect(page).to have_button('Save changes')
  end

  scenario 'opens commercial editing directly from the dossier' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier, return_to: 'commercial')
    expect(page).to have_css('[data-supplier-form-target="tab"][aria-current="location"][data-step-index="3"]',
                             visible: :all)
    expect(page).to have_css('[data-supplier-form-target="submit"]', visible: true)
  end

  scenario 'keeps supplier details available in the six editable sections' do
    supplier = create(:supplier, organization:, credit_days: 45, notes: 'Notas internas del proveedor')
    main_contact = supplier.contacts.create!(name: 'Contacto de ventas', primary: true)
    country = Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
    supplier.addresses.create!(
      country:, street: 'Avenida Reforma', exterior_number: '125',
      neighborhood: 'Centro', city: 'Ciudad de México', state: 'CDMX',
      postal_code: '06000', purpose: 'fiscal', primary: true
    )
    visit edit_admin_supplier_path(supplier)

    expect(page).to have_css('form[data-supplier-form-new-record-value="false"]', visible: :all)
    expect(page).to have_css('[data-supplier-form-target="tab"]', count: 6, visible: :all)
    expect(page).to have_css('[data-supplier-form-target="step"]', count: 6, visible: :all)
    expect(page).to have_no_css('[data-supplier-form-target="summary"]', visible: :all)
    expect(page).to have_css("input[name$='[name]'][value='Contacto de ventas']", visible: :all)
    expect(page).to have_css('input[name="supplier[credit_days]"][value="45"]', visible: :all)
    expect(page).to have_css('textarea[name="supplier[notes]"]',
                             text: 'Notas internas del proveedor', visible: :all)
    expect(page).to have_css('select[name="supplier[responsible_user_id]"]', visible: :all)
    expect(main_contact.reload.name).to eq('Contacto de ventas')
  end

end
