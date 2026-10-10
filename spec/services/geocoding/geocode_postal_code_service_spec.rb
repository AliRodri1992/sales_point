# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Geocoding::GeocodePostalCodeService do
  subject(:service) { described_class.new(postal_code, country) }

  let(:postal_code) { '06000' }
  let(:country) { 'MX' }
  let(:connection) { instance_double(Faraday::Connection) }
  let(:body) do
    {
      features: [
        {
          center: [-99.1332, 19.4326],
          place_name: 'Centro, Ciudad de México, México',
          relevance: 0.95
        }
      ]
    }.to_json
  end
  let(:response) { instance_double(Faraday::Response, success?: true, body:) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('MAPBOX_TOKEN').and_return('test-token')
    allow(service).to receive(:connection).and_return(connection)
    allow(connection).to receive(:get).and_return(response)
    Rails.cache.delete(service.send(:cache_key))
  end

  describe '#call' do
    it 'returns normalized coordinates and address data from Mapbox' do
      expect(service.call).to eq(
        lat: 19.4326,
        lng: -99.1332,
        full_address: 'Centro, Ciudad de México, México',
        relevance: 0.95
      )
    end

    it 'escapes the postal code query and includes the configured token' do
      service.call

      expect(connection).to have_received(:get).with(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/06000%2C+MX.json?access_token=test-token&limit=1'
      )
    end

    context 'when the response is unsuccessful' do
      let(:response) { instance_double(Faraday::Response, success?: false, body: body) }

      it 'returns nil' do
        expect(service.call).to be_nil
      end
    end

    context 'when the response body is blank' do
      let(:response) { instance_double(Faraday::Response, success?: true, body: '') }

      it 'returns nil' do
        expect(service.call).to be_nil
      end
    end

    context 'when Mapbox returns no features' do
      let(:body) { { features: [] }.to_json }

      it 'returns nil' do
        expect(service.call).to be_nil
      end
    end

    it 'caches a successful result for the same postal code and country' do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      first_result = service.call
      second_result = described_class.new(postal_code, country).call

      expect(second_result).to eq(first_result)
      expect(connection).to have_received(:get).once
    end
  end

    context 'when the response contains malformed JSON' do
      let(:body) { '{not valid json' }

      it 'raises a JSON parsing error rather than caching an invalid result' do
        expect { service.call }.to raise_error(JSON::ParserError)
      end
    end

    context 'when the features key is null' do
      let(:body) { { features: nil }.to_json }

      it 'returns nil' do
        expect(service.call).to be_nil
      end
    end


  describe 'cache key' do
    it 'is based on the postal code and country query' do
      expect(service.send(:cache_key)).to eq(
        "address:geocode:#{Digest::MD5.hexdigest('06000, MX')}"
      )
    end
  end
end
