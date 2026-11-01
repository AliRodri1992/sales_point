# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Goods receipt and purchase return association boundaries', type: :model do
  describe GoodsReceipt do
    let(:receipt) { described_class.new(organization_id: 1) }

    it 'rejects purchase order from a different organization' do
      allow(receipt).to receive(:purchase_order).and_return(double(organization_id: 2))
      receipt.send(:validate_order_organization)
      expect(receipt.errors[:purchase_order]).not_to be_empty
    end

    it 'allows matching order organization' do
      allow(receipt).to receive(:purchase_order).and_return(double(organization_id: 1))
      receipt.send(:validate_order_organization)
      expect(receipt.errors[:purchase_order]).to be_empty
    end

    it 'rejects branch from another organization' do
      allow(receipt).to receive(:branch).and_return(double(organization_id: 2))
      receipt.send(:validate_branch_organization)
      expect(receipt.errors[:branch]).not_to be_empty
    end

    it 'rejects branch mismatch with the purchase order' do
      allow(receipt).to receive(:purchase_order).and_return(double(branch_id: 10))
      allow(receipt).to receive(:branch).and_return(double(id: 11))
      receipt.send(:validate_order_branch)
      expect(receipt.errors[:branch]).not_to be_empty
    end

    it 'accepts matching receipt branch' do
      allow(receipt).to receive(:purchase_order).and_return(double(branch_id: 10))
      allow(receipt).to receive(:branch).and_return(double(id: 10))
      receipt.send(:validate_order_branch)
      expect(receipt.errors[:branch]).to be_empty
    end

    it 'skips branch checks until associations have been assigned' do
      receipt.send(:validate_order_branch)
      expect(receipt.errors[:branch]).to be_empty
    end
  end

  describe GoodsReceiptItem do
    it 'skips partial quantities and accepts consistent values' do
      item = described_class.new
      item.send(:quantities_consistent)
      expect(item.errors[:accepted_quantity]).to be_empty
      item.delivered_quantity = 5
      item.accepted_quantity = 3
      item.damaged_quantity = 2
      item.send(:quantities_consistent)
      expect(item.errors[:accepted_quantity]).to be_empty
    end

    it 'rejects accepted plus damaged amounts greater than delivery' do
      item = described_class.new(delivered_quantity: 3, accepted_quantity: 3, damaged_quantity: 1)
      item.send(:quantities_consistent)
      expect(item.errors[:accepted_quantity]).not_to be_empty
    end

    it 'does not check order matching without both associations' do
      item = described_class.new
      item.send(:order_item_consistent)
      expect(item.errors[:purchase_order_item]).to be_empty
    end

    it 'requires receipt items to belong to the same purchase order' do
      item = described_class.new
      allow(item).to receive(:goods_receipt).and_return(double(purchase_order_id: 1))
      allow(item).to receive(:purchase_order_item).and_return(double(purchase_order_id: 2))
      item.send(:order_item_consistent)
      expect(item.errors[:purchase_order_item]).not_to be_empty
    end

    it 'accepts matching order IDs' do
      item = described_class.new
      allow(item).to receive(:goods_receipt).and_return(double(purchase_order_id: 1))
      allow(item).to receive(:purchase_order_item).and_return(double(purchase_order_id: 1))
      item.send(:order_item_consistent)
      expect(item.errors[:purchase_order_item]).to be_empty
    end
  end

  describe PurchaseReturnItem do
    it 'skips comparison when either association is absent' do
      item = described_class.new
      item.send(:same_receipt)
      expect(item.errors[:goods_receipt_item]).to be_empty
    end

    it 'rejects an item for a different receipt' do
      item = described_class.new
      allow(item).to receive(:purchase_return).and_return(double(goods_receipt_id: 1))
      allow(item).to receive(:goods_receipt_item).and_return(double(goods_receipt_id: 2))
      item.send(:same_receipt)
      expect(item.errors[:goods_receipt_item]).not_to be_empty
    end

    it 'accepts an item from the same receipt' do
      item = described_class.new
      allow(item).to receive(:purchase_return).and_return(double(goods_receipt_id: 1))
      allow(item).to receive(:goods_receipt_item).and_return(double(goods_receipt_id: 1))
      item.send(:same_receipt)
      expect(item.errors[:goods_receipt_item]).to be_empty
    end
  end
end
