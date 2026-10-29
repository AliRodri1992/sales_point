# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier onboarding fiscal address validation', type: :feature, js: true do
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

  def choose_country(code)
    page.execute_script(<<~JS, code)
      const select = document.querySelector('select[name$="[country_id]"]')
      select.value = [...select.options].find((option) => option.dataset.countryCode === arguments[0]).value
      select.dispatchEvent(new Event("change", { bubbles: true }))
    JS
  end

  def open_fiscal_step
    visit new_admin_supplier_path
    find('input[name="supplier[code]"]').set('SUP-FISCAL-01')
    find('input[name="supplier[name]"]').set('Supplier Fiscal Validation')
    find('[data-action="supplier-form#next"]').click

    expect(page).to have_css('select[name="supplier[person_type]"]', visible: :all)
    page.execute_script(<<~JS)
      const select = document.querySelector('select[name="supplier[person_type]"]')
      select.value = "company"
      select.dispatchEvent(new Event("change", { bubbles: true }))
    JS
    find('input[name="supplier[rfc]"]').set('ABC010101ABC')
  end

  def fiscal_field(name)
    find("[data-supplier-address-validation] [data-supplier-address-field='#{name}']",
         visible: :all)
  end

  it 'blocks Next and displays every Mexican required-field error underneath its field' do
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
    open_fiscal_step
    choose_country('MX')
    find('[data-action="supplier-form#next"]').click

    %w[street exterior_number neighborhood city state postal_code].each do |field|
      expect(fiscal_field(field)).to have_css("[data-supplier-address-model-error='#{field}']:not(.hidden)")
      expect(fiscal_field(field)).to have_css('[aria-invalid="true"]', visible: :all)
    end
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="1"][aria-current="step"]',
                             visible: :all)

    {
      street: 'Avenida Reforma', exterior_number: '125', neighborhood: 'Centro',
      city: 'Ciudad de México', state: 'CDMX'
    }.each do |field, value|
      fiscal_field(field).find('input').set(value)
      expect(fiscal_field(field)).to have_no_css('[data-supplier-address-model-error]:not(.hidden)')
    end
    fiscal_field('postal_code').find('input').set('1234')
    find('[data-action="supplier-form#next"]').click
    expect(fiscal_field('postal_code')).to have_css('[data-supplier-address-model-error="postal_code"]:not(.hidden)')
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="1"][aria-current="step"]',
                             visible: :all)

    fiscal_field('postal_code').find('input').set('06000')
    find('[data-action="supplier-form#next"]').click
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="2"][aria-current="step"]',
                             visible: :all)
  end

  it 'highlights the country selector when no country has been chosen' do
    open_fiscal_step
    find('[data-action="supplier-form#next"]').click

    expect(fiscal_field('country_id')).to have_css(
      '[data-supplier-address-model-error="country_id"]:not(.hidden)'
    )
    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="1"][aria-current="step"]',
                             visible: :all)
  end

  it 'uses the same Address model to allow countries without postal codes' do
    Country.find_by(iso_alpha2: 'AE') || create(:country, iso_alpha2: 'AE')
    open_fiscal_step
    choose_country('AE')
    fiscal_field('street').find('input').set('Al Wasl Road')
    fiscal_field('city').find('input').set('Dubai')
    find('[data-action="supplier-form#next"]').click

    expect(page).to have_css('[data-supplier-form-target="tab"][data-step-index="2"][aria-current="step"]',
                             visible: :all)
    expect(fiscal_field('postal_code')).to have_no_css(
      '[data-supplier-address-model-error="postal_code"]:not(.hidden)'
    )
  end
end
