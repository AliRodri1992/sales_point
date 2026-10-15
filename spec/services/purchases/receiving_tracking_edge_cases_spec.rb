# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Receiving serial and returned stock edge cases', type: :service do
  describe Purchases::ReceiveStock do
    let(:product) { double(tracking_mode: 'none') }
    let(:receipt_item) do
      double(lot_code: nil, accepted_quantity: 2.to_d,
             damaged_quantity: 1.to_d, expires_on: nil,
             purchase_order_item: double(product:))
    end

    def receiver(data = {})
      described_class.new(item: receipt_item, data:)
    end

    it 'rejects missing lot code when product tracks lots' do
      allow(product).to receive(:tracking_mode).and_return('lot')
      expect { receiver.send(:validate_tracking!) }
        .to raise_error(ArgumentError, /Lot number required/)
    end

    it 'permits an unexpired nontracked product' do
      expect { receiver.send(:validate_tracking!) }.not_to raise_error
    end

    it 'rejects expired accepted inventory' do
      allow(receipt_item).to receive(:expires_on).and_return(Date.yesterday)
      expect { receiver.send(:validate_tracking!) }
        .to raise_error(ArgumentError, /Expired merchandise/)
    end

    it 'rejects duplicate serial numbers and incorrect serial counts' do
      allow(product).to receive(:tracking_mode).and_return('serial')
      expect do
        receiver(serial_numbers: %w[ABC ABC], damaged_serial_numbers: ['DEF'])
          .send(:validate_tracking!)
      end.to raise_error(ArgumentError, /Serial count/)
      expect { receiver(serial_numbers: ['ABC']).send(:validate_tracking!) }
        .to raise_error(ArgumentError, /Serial count/)
    end

    it 'accepts correct unique serial numbers' do
      allow(product).to receive(:tracking_mode).and_return('serial')
      expect do
        receiver(serial_numbers: %w[ABC XYZ], damaged_serial_numbers: ['DEF'])
          .send(:validate_tracking!)
      end.not_to raise_error
    end

    it 'requires whole numbers for serialized stock' do
      service = receiver
      expect(service.send(:valid_serial_quantity?, 1.5.to_d, %w[A B])).to be(false)
      expect(service.send(:valid_serial_quantity?, 2.to_d, %w[A B])).to be(true)
    end

    it 'recognizes blank and populated serial inputs' do
      service = receiver
      expect(service.send(:split_serials, nil)).to be_empty
      expect(service.send(:split_serials, 'ABC, XYZ;DEF')).to eq(%w[ABC XYZ DEF])
    end

    it 'skips empty lot creation and serials without a lot' do
      service = receiver
      expect(service.send(:create_lot, double, quantity: 0.to_d, status: :available)).to be_nil
      expect(service.send(:create_serials, nil, %w[A])).to be_nil
    end
  end

  describe Purchases::ProcessReturn do
    it 'skips quarantine serial verification when inventory is not serialized' do
      lot = double(inventory: double(product: double(tracking_serial?: false)))
      expect { described_class.return_quarantined_serials!(lot, 0.5.to_d) }.not_to raise_error
    end

    it 'rejects fractional returns of serialized units' do
      lot = double(inventory: double(product: double(tracking_serial?: true)))
      expect { described_class.return_quarantined_serials!(lot, 0.5.to_d) }
        .to raise_error(ArgumentError, /whole numbers/)
    end

    it 'rejects insufficient quarantined serial numbers' do
      relation = double
      allow(relation).to receive(:quarantined).and_return(relation)
      allow(relation).to receive(:order).and_return(relation)
      allow(relation).to receive(:limit).and_return(relation)
      allow(relation).to receive(:to_a).and_return([])
      lot = double(inventory: double(product: double(tracking_serial?: true)),
                   inventory_serials: relation)
      expect { described_class.return_quarantined_serials!(lot, 1.to_d) }
        .to raise_error(ArgumentError, /Insufficient quarantined serial/)
    end

    it 'marks serialized quarantined returns as returned' do
      serial = double
      allow(serial).to receive(:update!)
      relation = double
      allow(relation).to receive(:quarantined).and_return(relation)
      allow(relation).to receive(:order).and_return(relation)
      allow(relation).to receive(:limit).and_return(relation)
      allow(relation).to receive(:to_a).and_return([serial])
      lot = double(inventory: double(product: double(tracking_serial?: true)),
                   inventory_serials: relation)
      described_class.return_quarantined_serials!(lot, 1.to_d)
      expect(serial).to have_received(:update!).with(status: :returned)
    end
  end

  describe Inventories::FefoAllocator do
    it 'allows expired lots only when processing a return' do
      lot = double(expires_on: Date.yesterday)
      expect(described_class.expiration_allowed?(lot, 'sale')).to be(false)
      expect(described_class.expiration_allowed?(lot, 'return')).to be(true)
    end

    it 'permits unexpired and non-expiring lots' do
      expect(described_class.expiration_allowed?(double(expires_on: nil), 'sale')).to be(true)
      expect(described_class.expiration_allowed?(double(expires_on: Date.tomorrow), 'sale')).to be(true)
    end

    it 'rejects incorrect inventory, quantities, expiration and insufficient stock' do
      inventory = double(id: 1, stock: 5.to_d)
      lot = double(inventory_id: 1, available?: true, quantity: 4.to_d, expires_on: nil)
      expect(described_class.lot_eligible?(inventory:, lot:, quantity: 0.to_d, kind: 'sale')).to be(false)
      allow(lot).to receive(:inventory_id).and_return(9)
      expect(described_class.lot_eligible?(inventory:, lot:, quantity: 1.to_d, kind: 'sale')).to be(false)
      allow(lot).to receive(:inventory_id).and_return(1)
      allow(lot).to receive(:available?).and_return(false)
      expect(described_class.lot_eligible?(inventory:, lot:, quantity: 1.to_d, kind: 'sale')).to be(false)
      allow(lot).to receive(:available?).and_return(true)
      allow(lot).to receive(:expires_on).and_return(Date.yesterday)
      expect(described_class.lot_eligible?(inventory:, lot:, quantity: 1.to_d, kind: 'sale')).to be(false)
      allow(lot).to receive(:expires_on).and_return(nil)
      expect(described_class.lot_eligible?(inventory:, lot:, quantity: 6.to_d, kind: 'sale')).to be(false)
    end

    it 'permits an available lot with sufficient stock' do
      inventory = double(id: 1, stock: 5.to_d)
      lot = double(inventory_id: 1, available?: true, quantity: 4.to_d, expires_on: nil)
      expect(described_class.lot_eligible?(inventory:, lot:, quantity: 3.to_d, kind: 'sale')).to be(true)
    end
  end
end
