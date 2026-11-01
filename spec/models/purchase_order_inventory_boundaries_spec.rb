# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase order and stock boundary validation', type: :model do
  describe PurchaseOrder do
    let(:order) { described_class.new(organization_id: 1, branch_id: 2, supplier_id: 3) }

    it 'validates organization for the assigned branch and supplier' do
      allow(order).to receive(:branch).and_return(double(organization_id: 4))
      allow(order).to receive(:supplier).and_return(double(organization_id: 5))
      order.send(:validate_purchase_branch)
      order.send(:validate_purchase_supplier)
      expect(order.errors[:branch]).not_to be_empty
      expect(order.errors[:supplier]).not_to be_empty
    end

    it 'accepts a branch and supplier from the organization' do
      allow(order).to receive(:branch).and_return(double(organization_id: 1))
      allow(order).to receive(:supplier).and_return(double(organization_id: 1))
      order.send(:validate_purchase_branch)
      order.send(:validate_purchase_supplier)
      expect(order.errors[:branch]).to be_empty
      expect(order.errors[:supplier]).to be_empty
    end

    it 'requires the request to be approved and linked to the same branch' do
      allow(order).to receive(:purchase_request)
        .and_return(double(organization_id: 1, branch_id: 2, approved?: false))
      order.send(:validate_purchase_request)
      expect(order.errors[:purchase_request]).not_to be_empty
    end

    it 'accepts approved requests matching organization and branch' do
      allow(order).to receive(:purchase_request)
        .and_return(double(organization_id: 1, branch_id: 2, approved?: true))
      order.send(:validate_purchase_request)
      expect(order.errors[:purchase_request]).to be_empty
    end

    it 'skips absent purchase request and quotation' do
      order.send(:validate_purchase_request)
      order.send(:validate_purchase_quotation)
      expect(order.errors[:purchase_request]).to be_empty
      expect(order.errors[:purchase_quotation]).to be_empty
    end

    it 'requires quotations to match the supplier and organization' do
      quotation = double(organization_id: 2, supplier_id: 3, accepted?: true,
                         valid_until: Date.tomorrow, purchase_request_id: nil)
      allow(order).to receive(:purchase_quotation).and_return(quotation)
      order.send(:validate_purchase_quotation)
      expect(order.errors[:purchase_quotation]).not_to be_empty
    end

    it 'rejects expired, unaccepted or unrelated purchase quotations' do
      [
        [false, Date.tomorrow, nil],
        [true, Date.yesterday, nil],
        [true, Date.tomorrow, 99]
      ].each do |accepted, expires, request_id|
        order.errors.clear
        quotation = double(organization_id: 1, supplier_id: 3,
                           accepted?: accepted, valid_until: expires,
                           purchase_request_id: request_id)
        allow(order).to receive(:purchase_quotation).and_return(quotation)
        order.send(:validate_purchase_quotation)
        expect(order.errors[:purchase_quotation]).not_to be_empty
      end
    end

    it 'accepts an active quotation for the same supplier and organization' do
      quotation = double(organization_id: 1, supplier_id: 3, accepted?: true,
                         valid_until: nil, purchase_request_id: nil)
      allow(order).to receive(:purchase_quotation).and_return(quotation)
      order.send(:validate_purchase_quotation)
      expect(order.errors[:purchase_quotation]).to be_empty
    end

    it 'rejects purchase order items for another organization' do
      allow(order).to receive(:purchase_order_items)
        .and_return([double(product: double(organization_id: 2))])
      order.send(:validate_purchase_items)
      expect(order.errors[:purchase_order_items]).not_to be_empty
    end

    it 'ignores blank products and accepts matching organization products' do
      allow(order).to receive(:purchase_order_items)
        .and_return([double(product: nil), double(product: double(organization_id: 1))])
      order.send(:validate_purchase_items)
      expect(order.errors[:purchase_order_items]).to be_empty
    end
  end

  describe Inventory do
    let(:inventory) { described_class.new(organization_id: 1, stock: 2, min_stock: 3) }

    it 'rejects branch and product from other organizations' do
      allow(inventory).to receive(:branch).and_return(double(organization_id: 2))
      allow(inventory).to receive(:product).and_return(double(organization_id: 3))
      inventory.send(:consistent_organization)
      expect(inventory.errors[:branch]).not_to be_empty
      expect(inventory.errors[:product]).not_to be_empty
    end

    it 'accepts valid organization links' do
      allow(inventory).to receive(:branch).and_return(double(organization_id: 1))
      allow(inventory).to receive(:product).and_return(double(organization_id: 1))
      inventory.send(:consistent_organization)
      expect(inventory.errors[:branch]).to be_empty
      expect(inventory.errors[:product]).to be_empty
    end

    it 'rejects maximum stock below minimum stock' do
      inventory.max_stock = 2
      inventory.min_stock = 3
      inventory.send(:valid_stock_limits)
      expect(inventory.errors[:max_stock]).not_to be_empty
    end

    it 'accepts null or sufficiently high maximum stock limits' do
      inventory.max_stock = nil
      inventory.send(:valid_stock_limits)
      expect(inventory.errors[:max_stock]).to be_empty
      inventory.max_stock = 5
      inventory.send(:valid_stock_limits)
      expect(inventory.errors[:max_stock]).to be_empty
    end

    it 'flags low stock only when a positive minimum exists' do
      expect(inventory.low_stock?).to be(true)
      inventory.min_stock = 0
      expect(inventory.low_stock?).to be(false)
    end
  end

  describe InventoryLot do
    it 'rejects lots attached to inventory from another organization' do
      lot = described_class.new(organization_id: 1)
      allow(lot).to receive(:inventory).and_return(double(organization_id: 2))
      lot.send(:consistent_organization)
      expect(lot.errors[:inventory]).not_to be_empty
    end

    it 'accepts matching inventory organization' do
      lot = described_class.new(organization_id: 1)
      allow(lot).to receive(:inventory).and_return(double(organization_id: 1))
      lot.send(:consistent_organization)
      expect(lot.errors[:inventory]).to be_empty
    end
  end
end
