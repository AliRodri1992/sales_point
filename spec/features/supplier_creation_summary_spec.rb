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

  scenario 'shows only general and fiscal details in the new supplier summary' do
    visit new_admin_supplier_path
    expect(page).to have_css('form[data-supplier-form-new-record-value="true"]', visible: :all)

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
    expect(headings).to eq(%w[step_1 step_2].map do |step|
      I18n.t("admin.suppliers.onboarding.steps.#{step}")
    end)
    expect(summary).to have_text('SUP-SUMMARY-01')
    expect(summary).to have_text('XAXX010101000')
    expect(summary).to have_text('Avenida Reforma')
    expect(summary).to have_no_text('Notas del proveedor')
    expect(summary).to have_no_text('5534037737')
    expect(summary).to have_no_css('dd', text: '45', exact_text: true)
    expect(page).to have_css('[data-supplier-form-target="tab"]', count: 7, visible: :all)
    expect(page).to have_css('input[name$="[mobile_phone]"]', visible: :all)
    expect(page).to have_css('input[name="supplier[credit_days]"]', visible: :all)
    expect(page).to have_css('select[name="supplier[responsible_user_id]"]', visible: :all)
    expect(page).to have_css('textarea[name="supplier[notes]"]', visible: :all)
  end

  scenario 'shows only general and fiscal details when editing an existing supplier' do
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

    expect(headings).to eq(%w[step_1 step_2].map do |step|
      I18n.t("admin.suppliers.onboarding.steps.#{step}")
    end)
    expect(summary).to have_text(supplier.code)
    expect(summary).to have_text(supplier.rfc)
    expect(summary).to have_text('Avenida Reforma')
    expect(summary).to have_no_text('Contacto de ventas')
    expect(summary).to have_no_css('dd', text: '45', exact_text: true)
    expect(summary).to have_no_text('Notas internas del proveedor')

    # Only the summary is shortened; the remaining tabs and editable data stay in place.
    expect(page).to have_css('[data-supplier-form-target="tab"]', count: 7, visible: :all)
    expect(page).to have_css("input[name$='[name]'][value='Contacto de ventas']", visible: :all)
    expect(page).to have_css('input[name="supplier[credit_days]"][value="45"]', visible: :all)
    expect(page).to have_css('textarea[name="supplier[notes]"]',
                             text: 'Notas internas del proveedor', visible: :all)
    expect(page).to have_css('select[name="supplier[responsible_user_id]"]', visible: :all)
    expect(main_contact.reload.name).to eq('Contacto de ventas')
  end
end
