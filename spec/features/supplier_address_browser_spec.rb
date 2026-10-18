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
    unless page.has_css?('select[name="address[country_id]"]', visible: :all)
      raise "Supplier address form unavailable at #{page.current_url}: #{page.text.first(250)}"
    end

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
    neighborhood = find('input[name="address[neighborhood]"]', visible: :all)
    neighborhood.set('Centro')
    city = find('input[name="address[city]"]', visible: :all)
    city.set('Cuauhtémoc')
    choose_country('AE')

    expect(postal.value).to eq('')
    expect(neighborhood.value).to eq('')
    expect(city.value).to eq('')
    expect(page).to have_css('[data-country-postal-wrapper].hidden', visible: :all)

    choose_country('MX')
    expect(postal.value).to eq('06000')
    expect(neighborhood.value).to eq('Centro')
    expect(city.value).to eq('Cuauhtémoc')
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
    old_map = find('[data-supplier-address-location-target="mapImage"]', visible: :all)[:src]
    find('button[data-direction="right"]').click
    expect(find('[data-supplier-address-location-target="mapImage"]', visible: :all)[:src]).not_to eq(old_map)
    find('[data-action="supplier-address-location#confirm"]').click
    expect(page).to have_css('#supplier-location-reason-error:not(.hidden)', text: 'Adjustment reason cannot be blank')
    expect(find('input[name="address[location_confirmed]"]', visible: :all).value).to eq('0')

    find('input[name="address[location_adjustment_reason]"]').set('Adjusted marker after checking the entrance')
    find('[data-action="supplier-address-location#confirm"]').click
    expect(page).to have_css('#supplier-location-reason-error.hidden', visible: :all)

    expect(find('input[name="address[location_confirmed]"]', visible: :all).value).to eq('1')
    find('form[data-controller~="supplier-address-location"] button[type="submit"]').click
    expect(page).to have_current_path(admin_supplier_addresses_path(supplier), wait: 10)

    errors = page.all('[role="alert"], [data-server-field-error]', minimum: 0).map(&:text).join(' | ')
    expect(supplier.addresses.reload.last&.location_confirmed?).to be(true), "path=#{page.current_path} #{errors}"
  end

  scenario 'discards delayed geocoding responses after the address changes' do
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
    visit new_admin_supplier_address_path(supplier)
    choose_country('MX')
    find('input[name="address[street]"]').set('Avenida Reforma')
    page.execute_script(<<~JS)
      const originalFetch = window.fetch.bind(window)
      window.fetch = (url, options) => {
        if (String(url).includes('address_location_suggestion')) {
          return new Promise((resolve) => {
            window.releasePostalMapProposal = () => resolve({
              ok: true,
              json: async () => ({ latitude: 19.67, longitude: -99.18,
                confidence: 0.91, signature: 'obsolete-token' })
            })
          })
        }
        return originalFetch(url, options)
      }
    JS
    find('[data-action="supplier-address-location#lookup"]').click
    expect(page).to have_css('[data-supplier-address-location-target="lookupButton"]:disabled')
    find('input[name="address[street]"]').set('Calle Nueva')
    page.execute_script('window.releasePostalMapProposal()')

    expect(find('input[name="address[location_signature]"]', visible: :all).value).to eq('')
    expect(find('input[name="address[location_confirmed]"]', visible: :all).value).to eq('0')
  end

  scenario 'requires explicit review and reason for a low confidence marker' do
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
    suggestion = { valid: true, latitude: 19.6742, longitude: -99.1803,
                   full_address: 'Cuautitlán', confidence: 0.30 }
    allow_any_instance_of(Geocoding::MapboxValidateAddressService).to receive(:call).and_return(suggestion)
    visit new_admin_supplier_address_path(supplier)
    choose_country('MX')
    { street: 'Avenida Reforma', exterior_number: '125', neighborhood: 'Centro',
      city: 'Cuautitlán', state: 'Estado de México', postal_code: '54800' }.each do |field, value|
      find("input[name='address[#{field}]']", visible: :all).set(value)
    end
    find('input[name="address[purpose]"][value="delivery"]', visible: :all).set(true)
    find('[data-action="supplier-address-location#lookup"]').click
    expect(page).to have_css('[data-supplier-address-location-target="reviewFields"]:not(.hidden)')
    expect(page).to have_css('[data-supplier-address-location-target="reviewNotice"]:not(.hidden)',
                             text: 'Verify the physical address')
    find('[data-action="supplier-address-location#confirm"]').click
    expect(find('input[name="address[location_confirmed]"]', visible: :all).value).to eq('0')

    find('input[name="address[location_adjustment_reason]"]').set('Verifiqué la entrada principal')
    find('input[name="address[location_reviewed]"][type="checkbox"]').set(true)
    find('[data-action="supplier-address-location#confirm"]').click
    expect(find('input[name="address[location_confirmed]"]', visible: :all).value).to eq('1')
    find('form[data-controller~="supplier-address-location"] button[type="submit"]').click
    expect(page).to have_current_path(admin_supplier_addresses_path(supplier), wait: 10)
    expect(supplier.addresses.reload.last.geocoding_confidence.to_f).to eq(0.3)
  end
end
