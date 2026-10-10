# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Geocoding::MapboxValidateAddressService do
  subject(:service) { described_class.new(address) }

  let(:address) do
    instance_double(
      Address,
      street: 'Av. Juárez',
      exterior_number: '10',
      neighborhood: 'Centro',
      city: 'Ciudad de México',
      state: 'CDMX',
      country: 'México',
      postal_code: '06000'
    )
  end
  let(:response_body) do
    {
      features: [
        {
          place_name: 'Av. Juárez 10, Centro, Ciudad de México',
          center: [-99.1332, 19.4326],
          relevance: 0.95
        }
      ]
    }.to_json
  end
  let(:response) { instance_double(Faraday::Response, body: response_body) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('MAPBOX_TOKEN', nil).and_return('test-token')
    allow(Faraday).to receive(:get).and_return(response)
  end

  describe '#call' do
    it 'returns the first feature normalized as address data' do
      expect(service.call).to eq(
        valid: true,
        full_address: 'Av. Juárez 10, Centro, Ciudad de México',
        latitude: 19.4326,
        longitude: -99.1332,
        confidence: 0.95
      )
    end

    it 'requests Mapbox using the encoded address and token' do
      service.call

      expect(Faraday).to have_received(:get).with(
        %r{https://api\.mapbox\.com/geocoding/v5/mapbox\.places/.*\.json\?access_token=test-token&limit=1}
      )
    end

    context 'when no features are returned' do
      let(:response_body) { { features: [] }.to_json }

      it 'returns false' do
        expect(service.call).to be(false)
      end
    end

    context 'when the response is invalid JSON' do
      let(:response_body) { 'not-json' }

      it 'returns an invalid result' do
        expect(service.call).to eq(valid: false)
      end
    end

    context 'when the HTTP request raises an error' do
      before { allow(Faraday).to receive(:get).and_raise(Faraday::ConnectionFailed, 'offline') }

      it 'returns an invalid result' do
        expect(service.call).to eq(valid: false)
      end
    end

    it 'omits missing address components from the query' do
      allow(address).to receive(:exterior_number).and_return(nil)
      allow(address).to receive(:neighborhood).and_return(nil)

      service.send(:url)

      expect(Faraday).not_to have_received(:get)
    end
  end
end
