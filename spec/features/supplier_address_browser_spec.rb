# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier address browser workflow', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
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
      const select = document.querySelector('select[name="address[country_id]"]')
      select.value = select.querySelector('option[data-country-code="' + arguments[0] + '"]').value
      select.dispatchEvent(new Event('change', { bubbles: true }))
    JS
  end

  scenario 'keeps a Mexican postal draft while switching to a country without codes' do
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
    Country.find_by(iso_alpha2: 'AE') || create(:country, iso_alpha2: 'AE')
    visit new_admin_supplier_address_path(supplier)

    choose_country('MX')
    postal = find('input[name="address[postal_code]"]', visible: :all)
    postal.set('06000')
    choose_country('AE')

    expect(postal.value).to eq('')
    expect(page).to have_css('[data-country-postal-wrapper].hidden', visible: :all)

    choose_country('MX')
    expect(postal.value).to eq('06000')
  end

  scenario 'searches, adjusts using the keyboard and confirms a signed marker' do
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
    result = { valid: true, latitude: 19.6742, longitude: -99.1803,
               full_address: 'Avenida Reforma 125, Cuautitlán', confidence: 0.94 }
    allow_any_instance_of(Geocoding::MapboxValidateAddressService).to receive(:call).and_return(result)
    visit new_admin_supplier_address_path(supplier)

    choose_country('MX')
    { street: 'Avenida Reforma', exterior_number: '125', neighborhood: 'Centro',
      city: 'Cuautitlán', state: 'Estado de México', postal_code: '54800' }.each do |field, value|
      find("input[name='address[#{field}]']", visible: :all).set(value)
    end
    find('input[name="address[purpose]"][value="delivery"]', visible: :all).set(true)
    find('[data-action="supplier-address-location#lookup"]').click
    marker = find('[data-supplier-address-location-target="mapClick"]:not(.hidden)')
    marker.send_keys(:arrow_right)
    find('[data-action="supplier-address-location#confirm"]').click

    expect(find('input[name="address[location_confirmed]"]', visible: :all).value).to eq('1')
    find('form[data-controller~="supplier-address-location"] button[type="submit"]').click

    expect(supplier.addresses.last.location_confirmed?).to be true
  end
end
