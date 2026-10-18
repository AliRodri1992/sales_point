# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Geocoding::MapboxStaticMapService do
  let(:service) { described_class.new }
  let(:response) { instance_double(Faraday::Response, success?: true, body: 'map-image') }
  let(:connection) { instance_double(Faraday::Connection, get: response) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('MAPBOX_TOKEN').and_return('test-token')
    allow(service).to receive(:connection).and_return(connection)
  end

  it 'retrieves a real Mapbox style image for valid coordinates' do
    expect(service.call(latitude: 19.5, longitude: -99.1)).to eq('map-image')
    expect(connection).to have_received(:get).with(include('/-99.1,19.5,15,0/600x300'))
  end

  it 'rejects coordinates outside latitude and longitude ranges' do
    expect(service.call(latitude: 91, longitude: 10)).to be_nil
    expect(connection).not_to have_received(:get)
  end

  it 'handles Mapbox network errors without raising' do
    allow(connection).to receive(:get).and_raise(Faraday::TimeoutError)
    expect(service.call(latitude: 19.5, longitude: -99.1)).to be_nil
  end

  it 'never requests a map without a configured token' do
    allow(ENV).to receive(:[]).with('MAPBOX_TOKEN').and_return(nil)
    expect(service.call(latitude: 19.5, longitude: -99.1)).to be_nil
  end
end
