# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Geocoding and receipt idempotency decision paths', type: :service do
  describe AddressGeocodingService do
    let(:service) { described_class.allocate }

    it 'rejects empty geocoding results and missing coordinates' do
      expect(service.send(:valid_result?, nil)).to be(false)
      expect(service.send(:valid_result?, {})).to be(false)
      expect(service.send(:valid_result?, { lat: 12.0 })).to be(false)
      expect(service.send(:valid_result?, { lat: 12.0, lng: nil })).to be(false)
    end

    it 'accepts geocoding results containing latitude and longitude' do
      expect(service.send(:valid_result?, { lat: 12.0, lng: -99.0 })).to be(true)
    end

    it 'marks geocoding as failed when a provider raises' do
      address = double
      allow(address).to receive(:update!)
      service.instance_variable_set(:@address, address)
      allow(service).to receive(:geocode_address).and_raise(StandardError, 'offline')
      allow(service).to receive(:log_error)
      service.call
      expect(address).to have_received(:update!).with(geocoding_status: 'failed')
    end
  end

  describe Purchases::Receive do
    it 'returns an existing posted receipt without allocating stock twice' do
      order = double(organization: double, id: 1)
      original_receipt = double(purchase_order_id: 1, payload_digest: nil)
      allow(GoodsReceipt).to receive(:find_by).and_return(original_receipt)
      service = described_class.new(order:, user: double, idempotency_key: 'unique',
                                    entries: [], options: {})
      expect(service.call).to eq(original_receipt)
    end

    it 'updates the order to partially received when any item is outstanding' do
      item = double
      order = double(purchase_order_items: [item], outstanding_quantity_for: 2.to_d)
      allow(order).to receive(:update!)
      service = described_class.new(order:, user: double, idempotency_key: 'key',
                                    entries: [], options: {})
      service.send(:refresh_order_status!)
      expect(order).to have_received(:update!).with(status: :partially_received)
    end

    it 'updates the order to fully received when every item is satisfied' do
      item = double
      order = double(purchase_order_items: [item], outstanding_quantity_for: 0.to_d)
      allow(order).to receive(:update!)
      service = described_class.new(order:, user: double, idempotency_key: 'key',
                                    entries: [], options: {})
      service.send(:refresh_order_status!)
      expect(order).to have_received(:update!).with(status: :received)
    end
  end
end
