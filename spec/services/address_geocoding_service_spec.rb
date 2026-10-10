# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AddressGeocodingService do
  describe '#call' do
    let(:address) { create(:address) }
    let(:service) { described_class.new(address.id) }

    it 'updates a valid geocoding result' do
      result = { lat: 19.4, lng: -99.1 }

      allow(Geocoding::GeocodePostalCodeService).to receive(:new)
        .with(address.postal_code, address.country)
        .and_return(instance_double(Geocoding::GeocodePostalCodeService, call: result))

      service.call

      expect(address.reload).to have_attributes(
        latitude: 19.4,
        longitude: -99.1,
        geocoding_status: 'success'
      )
    end

    it 'does not update an invalid geocoding result' do
      allow(Geocoding::GeocodePostalCodeService).to receive(:new)
        .and_return(instance_double(Geocoding::GeocodePostalCodeService, call: {}))

      service.call

      expect(address.reload.geocoding_status).to eq('pending')
    end

    it 'does not update the address when the geocoding result is nil' do
      allow(Geocoding::GeocodePostalCodeService).to receive(:new)
        .and_return(instance_double(Geocoding::GeocodePostalCodeService, call: nil))

      service.call

      expect(address.reload.geocoding_status).to eq('pending')
    end

    it 'does not update the address when the result has no longitude' do
      allow(Geocoding::GeocodePostalCodeService).to receive(:new)
        .and_return(instance_double(Geocoding::GeocodePostalCodeService, call: { lat: 19.4 }))

      service.call

      expect(address.reload.geocoding_status).to eq('pending')
    end

    it 'marks the address as failed when geocoding raises' do
      allow(Geocoding::GeocodePostalCodeService).to receive(:new)
        .and_raise(StandardError, 'provider unavailable')

      service.call

      expect(address.reload.geocoding_status).to eq('failed')
    end
  end
end
