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

  def show_summary
    page.execute_script(<<~JS)
      const form = document.querySelector('form[data-controller="supplier-form"]')
      const controller = window.Stimulus.getControllerForElementAndIdentifier(form, 'supplier-form')
      controller.indexValue = controller.stepTargets.length - 1
    JS

    find('[data-supplier-form-target="summary"]')
  end

  scenario 'uses the available width and exposes section progress without a promotional panel' do
    visit new_admin_supplier_path

    expect(page).to have_css('[data-supplier-form-target="progress"]')
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-state]', count: 6, visible: :all)
    expect(page).to have_no_css('img[src*="supplier-delivery"]', visible: :all)
    expect(page).to have_css('form[data-controller="supplier-form"]')
    expect(page).to have_css('nav details[data-supplier-form-target="navigation"]')
    expect(page).to have_css('nav details [data-supplier-form-target="tab"]', count: 7, visible: :all)
    expect(page).to have_no_css('nav .overflow-x-auto', visible: :all)
    expect(page).to have_no_css('nav[class*="sticky"]', visible: :all)
  end

  scenario 'lets editors switch sections from a compact menu without reloading' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier)

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('button[data-step-index="3"]').click

    expect(page).to have_css('[data-supplier-form-target="activeLabel"]',
                             text: I18n.t('admin.suppliers.onboarding.steps.step_5'))
    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden)', count: 1)
    expect(page).to have_no_css('details[data-supplier-form-target="navigation"][open]', visible: :all)
  end

  scenario 'closes section picker on Escape and restores keyboard focus' do
    visit new_admin_supplier_path
    navigation = find('details[data-supplier-form-target="navigation"]')
    summary = navigation.find('summary')
    summary.click
    expect(page).to have_css('details[data-supplier-form-target="navigation"][open]', visible: :all)

    summary.send_keys(:escape)

    expect(page).to have_no_css('details[data-supplier-form-target="navigation"][open]', visible: :all)
    expect(page.evaluate_script("document.activeElement.tagName")).to eq('SUMMARY')
  end

  scenario 'keeps the compact navigation inside the viewport on mobile' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_admin_supplier_path

    expect(page).to have_css('details[data-supplier-form-target="navigation"] > summary', visible: true)
    expect(page).to have_css('[data-supplier-form-target="position"]', visible: true)
    expect(page.evaluate_script(<<~JS)).to be(true)
      const nav = document.querySelector('nav[aria-label] details[data-supplier-form-target="navigation"]')
      const bounds = nav.getBoundingClientRect()
      bounds.left >= 0 && bounds.right <= window.innerWidth
    JS
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  scenario 'summarizes all editable steps in the new supplier review' do
    visit new_admin_supplier_path
    expect(page).to have_css('form[data-supplier-form-new-record-value="true"]', visible: :all)
    expect(page).to have_css('input[type="submit"][value="Create supplier"]', visible: :all)

    page.execute_script(<<~JS)
      const form = document.querySelector('form[data-controller="supplier-form"]')
      form.querySelector('input[name="supplier[code]"]').value = 'SUP-SUMMARY-01'
      form.querySelector('input[name="supplier[rfc]"]').value = 'XAXX010101000'
      form.querySelector('input[name$="[street]"]').value = 'Avenida Reforma'
      form.querySelector('input[name$="[mobile_phone]"]').value = '5534037737'
      form.querySelector('input[name="supplier[credit_days]"]').value = '45'
      form.querySelector('textarea[name="supplier[notes]"]').value = 'Notas del proveedor'
    JS

    summary = show_summary
    headings = summary.all('h3').map(&:text)
    %w[step_1 step_2 step_3 step_5 step_6 step_7].each do |step|
      label = I18n.t("admin.suppliers.onboarding.steps.#{step}")
      expect(headings.any? { |heading| heading.start_with?(label) }).to be(true)
    end
    expect(summary).to have_text('SUP-SUMMARY-01')
    expect(summary).to have_text('XAXX010101000')
    expect(summary).to have_text('Avenida Reforma')
    expect(summary).to have_text('Notas del proveedor')
    expect(summary).to have_text('5534037737')
    expect(summary).to have_css('dd', text: '45', exact_text: true)
    expect(page).to have_css('[data-supplier-form-target="tab"]', count: 7, visible: :all)
    expect(page).to have_css('[data-step-indicator]', count: 6, visible: :all)
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-state]', count: 6, visible: :all)
    expect(page).to have_css('input[name$="[mobile_phone]"]', visible: :all)
    expect(page).to have_css('input[name="supplier[credit_days]"]', visible: :all)
    expect(page).to have_css('select[name="supplier[responsible_user_id]"]', visible: :all)
    expect(page).to have_css('textarea[name="supplier[notes]"]', visible: :all)
  end

  scenario 'opens the fiscal editing section directly and keeps save available' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier, return_to: 'fiscal')

    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden)', count: 1)
    expect(page).to have_css('[data-supplier-form-target="tab"][aria-current="step"][data-step-index="1"]')
    expect(page).to have_css('[data-supplier-form-target="submit"]', visible: true)
  end

  scenario 'lets existing suppliers move between editing sections without onboarding validation' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier)

    find('[data-supplier-form-target="tab"][data-step-index="1"]').click
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="1"][aria-current="step"]')
    find('[data-supplier-form-target="tab"][data-step-index="3"]').click
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="3"][aria-current="step"]')
    expect(page).to have_button('Save changes')
  end

  scenario 'opens commercial editing directly from the dossier' do
    supplier = create(:supplier, organization:)
    visit edit_admin_supplier_path(supplier, return_to: 'commercial')
    expect(page).to have_css('[data-supplier-form-target="tab"][aria-current="step"][data-step-index="3"]')
    expect(page).to have_css('[data-supplier-form-target="submit"]', visible: true)
  end

  scenario 'summarizes all editable steps when editing a supplier' do
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
    summary = show_summary
    headings = summary.all('h3').map(&:text)

    %w[step_1 step_2 step_3 step_5 step_6 step_7].each do |step|
      label = I18n.t("admin.suppliers.onboarding.steps.#{step}")
      expect(headings.any? { |heading| heading.start_with?(label) }).to be(true)
    end
    expect(summary).to have_text(supplier.code)
    expect(summary).to have_text(supplier.rfc)
    expect(summary).to have_text('Avenida Reforma')
    expect(summary).to have_text('Contacto de ventas')
    expect(summary).to have_css('dd', text: '45', exact_text: true)
    expect(summary).to have_text('Notas internas del proveedor')

    # All data and all editable tabs remain available before saving.
    expect(page).to have_css('[data-supplier-form-target="tab"]', count: 7, visible: :all)
    expect(page).to have_css("input[name$='[name]'][value='Contacto de ventas']", visible: :all)
    expect(page).to have_css('input[name="supplier[credit_days]"][value="45"]', visible: :all)
    expect(page).to have_css('textarea[name="supplier[notes]"]',
                             text: 'Notas internas del proveedor', visible: :all)
    expect(page).to have_css('select[name="supplier[responsible_user_id]"]', visible: :all)
    expect(main_contact.reload.name).to eq('Contacto de ventas')
  end
end
