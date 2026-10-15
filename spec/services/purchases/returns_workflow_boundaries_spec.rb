# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Return and approval boundary decisions', type: :service do
  describe Purchases::ProcessReturn do
    def locked_return(draft:, items:)
      goods = double
      allow(goods).to receive(:with_lock).and_yield
      record = double(goods_receipt: goods, draft?: draft, purchase_return_items: items)
      allow(record).to receive(:with_lock).and_yield
      record
    end

    it 'rejects a finalized return even when it has items' do
      record = locked_return(draft: false, items: [double])
      expect { described_class.call(purchase_return: record, user: double) }
        .to raise_error(ArgumentError, /already finalized/)
    end

    it 'rejects a draft return without any items' do
      record = locked_return(draft: true, items: [])
      expect { described_class.call(purchase_return: record, user: double) }
        .to raise_error(ArgumentError, /requires items/)
    end

    it 'processes an empty available-lot collection as insufficient stock' do
      lots = double
      allow(lots).to receive(:available).and_return(lots)
      allow(lots).to receive(:where).and_return(lots)
      allow(lots).to receive(:order).and_return([])
      item = double(inventory_lots: lots)
      entry = double(quantity: 1.to_d, goods_receipt_item: item)
      expect { described_class.return_accepted!(entry, user: double) }
        .to raise_error(ArgumentError, /Not enough stock/)
    end

    it 'rejects a shortage of quarantined stock' do
      lots = double
      allow(lots).to receive(:quarantined).and_return(lots)
      allow(lots).to receive(:where).and_return(lots)
      allow(lots).to receive(:order).and_return([])
      item = double(inventory_lots: lots)
      entry = double(quantity: 1.to_d, goods_receipt_item: item)
      expect { described_class.return_quarantined!(entry) }
        .to raise_error(ArgumentError, /Not enough quarantined/)
    end
  end

  describe Purchases::Workflow do
    def with_locked_order(action:, status:, receipts_exist: false, items: [])
      order = double(status:, goods_receipts: double(exists?: receipts_exist),
                     purchase_order_items: items, requested_by_id: 4)
      allow(order).to receive(:with_lock).and_yield
      Purchases::Workflow.new(order:, action:, user: double(id: 4), notes: nil)
    end

    it 'prevents cancellation when merchandise was received' do
      workflow = with_locked_order(action: :cancel, status: 'ordered', receipts_exist: true)
      expect { workflow.call }.to raise_error(ArgumentError, /cannot be cancelled/)
    end

    it 'requires items when submitting a purchase order' do
      workflow = with_locked_order(action: :submit, status: 'draft')
      expect { workflow.call }.to raise_error(ArgumentError, /needs items/)
    end

    it 'prevents approving an order requested by the same user' do
      workflow = with_locked_order(action: :approve, status: 'pending_approval')
      expect { workflow.call }.to raise_error(ArgumentError, /own order/)
    end
  end
end
