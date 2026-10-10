# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeocodeAddressJob, type: :job do
  describe '#perform' do
    it 'delegates geocoding to the address geocoding service' do
      address_id = 42
      service = instance_double(AddressGeocodingService, call: true)

      allow(AddressGeocodingService).to receive(:new).with(address_id).and_return(service)

      described_class.perform_now(address_id)

      expect(service).to have_received(:call)
    end

    it 'propagates record-not-found errors for the configured discard handler' do
      allow(AddressGeocodingService).to receive(:new).and_raise(ActiveRecord::RecordNotFound)

      expect { described_class.perform_now(999_999) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'logs fatal errors through the configured discard handler' do
      error = StandardError.new('fatal geocoding error')
      service = instance_double(AddressGeocodingService)
      logger = double('logger', error: nil)

      allow(AddressGeocodingService).to receive(:new).with(1).and_return(service)
      allow(service).to receive(:call).and_raise(error)
      allow(Rails).to receive(:logger).and_return(logger)

      described_class.perform_now(1)

      expect(logger).to have_received(:error).with('[GeocodeAddressJob] Fatal: fatal geocoding error')
    end
  end
end
