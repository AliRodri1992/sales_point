# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Geocoding::MapboxValidateAddressService do
  let(:address) { build(:address, street: 'Av. Juárez', country: build(:country, iso_alpha2: 'MX')) }
  let(:body) do
    { features: [{ place_name: 'Av. Juárez 10', center: [-99.1332, 19.4326], relevance: 0.95 }] }.to_json
  end
  let(:response) { instance_double(Faraday::Response, success?: true, body:) }
  let(:connection) { instance_double(Faraday::Connection, get: response) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('MAPBOX_TOKEN').and_return('test-token')
    allow_any_instance_of(described_class).to receive(:connection).and_return(connection)
  end

  it 'uses the complete address and returns coordinates' do
    result = described_class.new(address).call
    expect(result).to include(valid: true, latitude: 19.4326, longitude: -99.1332)
    expect(connection).to have_received(:get).with(include('Av.', 'test-token'))
  end

  it 'returns an invalid result when the provider has no matches' do
    allow(response).to receive(:body).and_return({ features: [] }.to_json)
    expect(described_class.new(address).call).to eq(valid: false)
  end

  it 'handles a network failure without raising' do
    allow(connection).to receive(:get).and_raise(Faraday::TimeoutError)
    expect(described_class.new(address).call).to eq(valid: false)
  end

  it 'skips requests without an API token' do
    allow(ENV).to receive(:[]).with('MAPBOX_TOKEN').and_return(nil)
    expect(described_class.new(address).call).to eq(valid: false)
    expect(connection).not_to have_received(:get)
  end

  it 'rejects a failed provider response without attempting to parse it' do
    allow(response).to receive(:success?).and_return(false)

    expect(described_class.new(address).call).to eq(valid: false)
  end

  it 'rejects invalid or out-of-range geographic coordinates' do
    invalid = { features: [{ center: [-200, 95], place_name: 'Untrusted location' }] }
    allow(response).to receive(:body).and_return(invalid.to_json)

    expect(described_class.new(address).call).to eq(valid: false)
  end

  it 'handles malformed provider JSON as an invalid location' do
    allow(response).to receive(:body).and_return('{not-json}')

    expect(described_class.new(address).call).to eq(valid: false)
  end

  it 'rejects incomplete location data instead of trusting a partial result' do
    invalid = { features: [{ place_name: 'Missing latitude', center: [-99.13] }] }
    allow(response).to receive(:body).and_return(invalid.to_json)

    expect(described_class.new(address).call).to eq(valid: false)
  end
end
