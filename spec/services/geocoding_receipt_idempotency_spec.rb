# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Geocoding and receipt idempotency decision paths', type: :service do
  describe AddressGeocodingService do
    let(:address) { create(:address, latitude: nil, longitude: nil) }
    let(:service) { described_class.new(address.id, address.geocoding_fingerprint) }

    it 'rejects empty or missing coordinates from the provider' do
      mock = instance_double(Geocoding::MapboxValidateAddressService, call: { valid: false })
      allow(Geocoding::MapboxValidateAddressService).to receive(:new).and_return(mock)

      service.call

      expect(address.reload.latitude).to be_nil
      expect(address.reload.geocoding_status).to eq('failed')
    end

    it 'accepts a full-address match and records its coordinates' do
      result = { valid: true, latitude: 12.0, longitude: -99.0 }
      mock = instance_double(Geocoding::MapboxValidateAddressService, call: result)
      allow(Geocoding::MapboxValidateAddressService).to receive(:new).and_return(mock)

      service.call

      expect(address.reload.coordinates.map(&:to_f)).to eq([12.0, -99.0])
    end

    it 'marks geocoding as failed if the provider raises unexpectedly' do
      allow(Geocoding::MapboxValidateAddressService).to receive(:new).and_raise(StandardError, 'offline')
      allow(Rails.logger).to receive(:error)

      service.call

      expect(address.reload.geocoding_status).to eq('failed')
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
