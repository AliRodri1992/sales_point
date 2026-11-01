# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase workflow and idempotency edge cases', type: :service do
  describe Purchases::Workflow do
    def locked_request(**attributes)
      request = double(**attributes)
      allow(request).to receive(:with_lock).and_yield
      request
    end

    it 'rejects submission of an already submitted request' do
      request = locked_request(draft?: false)
      expect { described_class.submit_request!(request) }
        .to raise_error(ArgumentError, /not a draft/)
    end

    it 'rejects submission without line items' do
      request = locked_request(draft?: true, purchase_request_items: [])
      expect { described_class.submit_request!(request) }
        .to raise_error(ArgumentError, /needs items/)
    end

    it 'submits a draft with items' do
      request = locked_request(draft?: true, purchase_request_items: [double])
      allow(request).to receive(:update!)
      described_class.submit_request!(request)
      expect(request).to have_received(:update!).with(hash_including(status: :submitted))
    end

    it 'rejects decision on non-submitted requests' do
      request = locked_request(submitted?: false)
      expect { described_class.decide_request!(request, status: 'approved', user: double(id: 5)) }
        .to raise_error(ArgumentError, /must be submitted/)
    end

    it 'rejects unsupported decision states' do
      request = locked_request(submitted?: true)
      expect { described_class.decide_request!(request, status: 'cancelled', user: double(id: 5)) }
        .to raise_error(ArgumentError, /Unsupported/)
    end

    it 'prevents a requester approving their own purchase' do
      request = locked_request(submitted?: true, requested_by_id: 5)
      expect { described_class.decide_request!(request, status: 'approved', user: double(id: 5)) }
        .to raise_error(ArgumentError, /own request/)
    end

    it 'accepts approval and rejection decisions by another user' do
      %w[approved rejected].each do |status|
        request = locked_request(submitted?: true, requested_by_id: 5)
        allow(request).to receive(:update!)
        described_class.decide_request!(request, status:, user: double(id: 6))
        expect(request).to have_received(:update!).with(status:)
      end
    end

    it 'rejects closing an order without any receipts' do
      supplier = double
      allow(supplier).to receive(:with_lock).and_yield
      order = double(status: 'ordered', goods_receipts: double(exists?: false), supplier:)
      allow(order).to receive(:with_lock).and_yield
      instance = described_class.new(order:, action: :close, user: double(id: 3), notes: nil)
      expect { instance.call }.to raise_error(ArgumentError, /Cannot close before receiving/)
    end

    it 'rejects unsupported order status transitions' do
      supplier = double
      allow(supplier).to receive(:with_lock).and_yield
      order = double(status: 'received', supplier:)
      allow(order).to receive(:with_lock).and_yield
      instance = described_class.new(order:, action: :approve, user: double(id: 3), notes: nil)
      expect { instance.call }.to raise_error(ArgumentError, /Invalid order status transition/)
    end
  end

  describe Purchases::Receive do
    let(:order) { double(organization: double, id: 5, receivable?: true) }

    def receiver(key: 'key', entries: [{ purchase_order_item_id: 3 }])
      described_class.new(order:, user: double, idempotency_key: key,
                          entries:, options: {})
    end

    it 'does not attempt idempotency lookup without a key' do
      expect(receiver(key: nil).send(:existing)).to be_nil
    end

    it 'rejects key reuse on a different order' do
      receipt = double(purchase_order_id: 99)
      allow(GoodsReceipt).to receive(:find_by).and_return(receipt)
      expect { receiver.send(:existing) }.to raise_error(ArgumentError, /different purchase order/)
    end

    it 'rejects key reuse with a changed payload' do
      receipt = double(purchase_order_id: 5, payload_digest: 'incorrect')
      allow(GoodsReceipt).to receive(:find_by).and_return(receipt)
      expect { receiver.send(:existing) }.to raise_error(ArgumentError, /different receiving details/)
    end

    it 'returns a matched idempotent receipt' do
      receipt = double(purchase_order_id: 5, payload_digest: nil)
      allow(GoodsReceipt).to receive(:find_by).and_return(receipt)
      expect(receiver.send(:existing)).to eq(receipt)
    end

    it 'returns nil for an unseen idempotency key' do
      allow(GoodsReceipt).to receive(:find_by).and_return(nil)
      expect(receiver.send(:existing)).to be_nil
    end

    it 'rejects blank keys, unsent orders and missing receipt items' do
      expect { receiver(key: nil).send(:validate_order!) }
        .to raise_error(ArgumentError, /unique operation key/)
      allow(order).to receive(:receivable?).and_return(false)
      expect { receiver.send(:validate_order!) }
        .to raise_error(ArgumentError, /sent before receiving/)
      allow(order).to receive(:receivable?).and_return(true)
      expect { receiver(entries: []).send(:validate_order!) }
        .to raise_error(ArgumentError, /must contain items/)
      expect { receiver.send(:validate_order!) }.not_to raise_error
    end

    it 'distinguishes payloads by their contents regardless of hash key order' do
      left = receiver(entries: [{ purchase_order_item_id: 3, delivered_quantity: '1' }])
      right = receiver(entries: [{ delivered_quantity: '1', purchase_order_item_id: 3 }])
      expect(left.send(:payload_digest)).to eq(right.send(:payload_digest))
      expect(left.send(:payload_digest)).not_to eq(receiver.send(:payload_digest))
    end
  end
end
