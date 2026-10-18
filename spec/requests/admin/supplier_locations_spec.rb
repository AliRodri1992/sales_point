# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier location verification', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }
  let(:country) do
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
  end
  let(:fields) do
    { country_id: country.id, street: 'Avenida Reforma',
      exterior_number: '125', neighborhood: 'Centro', city: 'Cuautitlán',
      state: 'Estado de México', postal_code: '54800' }
  end
  let(:result) do
    { valid: true, latitude: 19.6742, longitude: -99.1803,
      full_address: 'Avenida Reforma 125, Cuautitlán', confidence: 0.94 }
  end

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def fake_geocoder(value = result)
    allow_any_instance_of(Geocoding::MapboxValidateAddressService).to receive(:call).and_return(value)
  end

  it 'returns signed full-address geocoding suggestions, not provider tokens' do
    fake_geocoder
    post address_location_suggestion_admin_supplier_path(supplier), params: { address: fields }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('latitude' => 19.6742, 'longitude' => -99.1803)
    expect(response.parsed_body).to have_key('signature')
    expect(response.body).not_to include('access_token')
  end

  it 'saves a user-adjusted marker only with a signature matching the current address' do
    fake_geocoder
    post address_location_suggestion_admin_supplier_path(supplier), params: { address: fields }
    signature = response.parsed_body.fetch('signature')
    attributes = fields.merge(purpose: 'delivery', primary: false,
                              latitude: '19.675000', longitude: '-99.182000',
                              location_confirmed: '1', location_signature: signature)

    post admin_supplier_addresses_path(supplier), params: { address: attributes }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    address = supplier.addresses.last
    expect(address.location_confirmed?).to be true
    expect(address.reload.coordinates.map(&:to_f)).to eq([19.675, -99.182])
  end

  it 'rejects stale signatures when the text of the address changes' do
    fake_geocoder
    post address_location_suggestion_admin_supplier_path(supplier), params: { address: fields }
    signature = response.parsed_body.fetch('signature')
    attributes = fields.merge(street: 'Changed street', location_confirmed: '1',
                              location_signature: signature, latitude: '19.67', longitude: '-99.18')

    post admin_supplier_addresses_path(supplier), params: { address: attributes }

    expect(response).to have_http_status(:unprocessable_content)
    expect(supplier.addresses.count).to eq(0)
  end

  it 'automatically enqueues full-address geocoding when the location is not confirmed' do
    allow(GeocodeAddressJob).to receive(:perform_later)

    post admin_supplier_addresses_path(supplier), params: { address: fields }

    address = supplier.addresses.last
    expect(address).to be_present
    expect(GeocodeAddressJob).to have_received(:perform_later).with(address.id, address.geocoding_fingerprint)
  end

  it 'invalidates coordinates and re-enqueues geocoding after an address edit' do
    address = create(:address, addressable: supplier)
    address.update!(location_confirmed_at: Time.current, geocoding_status: :success)
    allow(GeocodeAddressJob).to receive(:perform_later)

    patch admin_supplier_address_path(supplier, address), params: {
      address: fields.merge(street: 'New Address', primary: false)
    }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(address.reload).to have_attributes(latitude: nil, longitude: nil,
                                              location_confirmed_at: nil, geocoding_status: 'pending')
    expect(GeocodeAddressJob).to have_received(:perform_later).with(address.id, address.geocoding_fingerprint)
  end

  it 'blocks another organization from requesting address previews and maps' do
    other = create(:supplier, organization: create(:organization))

    post address_location_suggestion_admin_supplier_path(other), params: { address: fields }
    expect(response).to have_http_status(:not_found)

    get address_map_admin_supplier_path(other), params: { latitude: 19.5, longitude: -99.1 }
    expect(response).to have_http_status(:not_found)
  end

  it 'returns a map image using the authenticated proxy' do
    allow_any_instance_of(Geocoding::MapboxStaticMapService).to receive(:call).and_return('image-bytes')

    get address_map_admin_supplier_path(supplier), params: { latitude: 19.5, longitude: -99.1 }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('image/png')
    expect(response.body).to eq('image-bytes')
  end

  it 'leaves manual capture available when geocoding is unavailable' do
    fake_geocoder(valid: false)
    post address_location_suggestion_admin_supplier_path(supplier), params: { address: fields }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq('error' => 'location_unavailable')

    post admin_supplier_addresses_path(supplier), params: { address: fields }
    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(supplier.addresses.count).to eq(1)
  end
  it 'rejects arbitrary distant markers even with a valid address proof' do
    fake_geocoder
    post address_location_suggestion_admin_supplier_path(supplier), params: { address: fields }
    signature = response.parsed_body.fetch('signature')
    attributes = fields.merge(purpose: 'delivery', primary: false,
                              latitude: '20.000000', longitude: '-99.180300',
                              location_confirmed: '1', location_signature: signature)

    post admin_supplier_addresses_path(supplier), params: { address: attributes }

    expect(response).to have_http_status(:unprocessable_content)
    expect(supplier.addresses.count).to eq(0)
  end

  it 'records a justified distant marker adjustment' do
    fake_geocoder
    post address_location_suggestion_admin_supplier_path(supplier), params: { address: fields }
    signature = response.parsed_body.fetch('signature')
    attributes = fields.merge(purpose: 'delivery', primary: false,
                              latitude: '20.000000', longitude: '-99.180300',
                              location_confirmed: '1', location_signature: signature,
                              location_adjustment_reason: 'Acceso real por carretera diferente')

    post admin_supplier_addresses_path(supplier), params: { address: attributes }

    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
    expect(supplier.addresses.last.location_adjustment_reason).to be_present
  end

end
