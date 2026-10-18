# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AddressGeocodingService do
  let(:address) { create(:address, latitude: nil, longitude: nil) }
  let(:result) { { valid: true, latitude: 19.4, longitude: -99.1 } }

  before do
    allow(Geocoding::MapboxValidateAddressService).to receive(:new)
      .and_return(instance_double(Geocoding::MapboxValidateAddressService, call: result))
  end

  it 'saves coordinates using the full-address provider' do
    described_class.new(address.id, address.geocoding_fingerprint).call

    expect(address.reload).to have_attributes(
      latitude: 19.4, longitude: -99.1, geocoding_status: 'success'
    )
    expect(address.location_confirmed?).to be false
  end

  it 'does not overwrite coordinates when the address has since changed' do
    before = address.geocoding_fingerprint
    address.update!(street: 'Different Street')

    described_class.new(address.id, before).call

    expect(address.reload.latitude).to be_nil
  end

  it 'does not overwrite user-confirmed locations' do
    address.update!(location_confirmed_at: Time.current, latitude: 19.5, longitude: -99.3)
    described_class.new(address.id, address.geocoding_fingerprint).call

    expect(address.reload.latitude.to_f).to eq(19.5)
  end

  it 'keeps a failed response from providing fake coordinates' do
    allow(Geocoding::MapboxValidateAddressService).to receive(:new)
      .and_return(instance_double(Geocoding::MapboxValidateAddressService, call: { valid: false }))

    described_class.new(address.id, address.geocoding_fingerprint).call

    expect(address.reload.geocoding_status).to eq('failed')
    expect(address.reload.latitude).to be_nil
  end
end
