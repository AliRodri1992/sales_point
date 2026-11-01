# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase line association validations', type: :model do
  describe SupplierInvoiceReceipt do
    it 'skips missing invoice or receipt' do
      item = described_class.new
      item.send(:matching_purchase)
      expect(item.errors[:goods_receipt]).to be_empty
    end

    it 'accepts a receipt from the same purchase and organization' do
      item = described_class.new
      allow(item).to receive(:supplier_invoice).and_return(double(organization_id: 1, purchase_order_id: 10))
      allow(item).to receive(:goods_receipt).and_return(double(organization_id: 1, purchase_order_id: 10))
      item.send(:matching_purchase)
      expect(item.errors[:goods_receipt]).to be_empty
    end

    it 'rejects a receipt from a different purchase order' do
      item = described_class.new
      allow(item).to receive(:supplier_invoice).and_return(double(organization_id: 1, purchase_order_id: 10))
      allow(item).to receive(:goods_receipt).and_return(double(organization_id: 1, purchase_order_id: 11))
      item.send(:matching_purchase)
      expect(item.errors[:goods_receipt]).not_to be_empty
    end

    it 'rejects a receipt from a different organization' do
      item = described_class.new
      allow(item).to receive(:supplier_invoice).and_return(double(organization_id: 1, purchase_order_id: 10))
      allow(item).to receive(:goods_receipt).and_return(double(organization_id: 2, purchase_order_id: 10))
      item.send(:matching_purchase)
      expect(item.errors[:goods_receipt]).not_to be_empty
    end
  end

  describe PurchaseOrderItem do
    it 'validates product organization only when both associations exist' do
      item = described_class.new
      item.send(:product_organization_consistent)
      expect(item.errors[:product]).to be_empty
      allow(item).to receive(:purchase_order).and_return(double(organization_id: 1))
      allow(item).to receive(:product).and_return(double(organization_id: 2))
      item.send(:product_organization_consistent)
      expect(item.errors[:product]).not_to be_empty
    end

    it 'allows a matching product and a matching supplier product' do
      item = described_class.new(product_id: 4)
      allow(item).to receive(:purchase_order).and_return(double(organization_id: 1, supplier_id: 2))
      allow(item).to receive(:product).and_return(double(organization_id: 1))
      allow(item).to receive(:supplier_product).and_return(double(organization_id: 1, supplier_id: 2, product_id: 4))
      item.send(:product_organization_consistent)
      item.send(:supplier_product_consistent)
      expect(item.errors[:product]).to be_empty
      expect(item.errors[:supplier_product]).to be_empty
    end

    it 'rejects a supplier product for a different supplier' do
      item = described_class.new(product_id: 4)
      allow(item).to receive(:purchase_order).and_return(double(organization_id: 1, supplier_id: 2))
      allow(item).to receive(:supplier_product).and_return(double(organization_id: 1, supplier_id: 3, product_id: 4))
      item.send(:supplier_product_consistent)
      expect(item.errors[:supplier_product]).not_to be_empty
    end
  end

  describe PurchaseQuotationItem do
    it 'ignores absent quotation and accepts matching product' do
      item = described_class.new(product_id: 4)
      item.send(:consistent_links)
      expect(item.errors[:product]).to be_empty
      allow(item).to receive(:purchase_quotation).and_return(double(organization_id: 1, supplier_id: 2))
      allow(item).to receive(:product).and_return(double(organization_id: 1))
      item.send(:consistent_links)
      expect(item.errors[:product]).to be_empty
    end

    it 'rejects cross-organization product and supplier links' do
      item = described_class.new(product_id: 4)
      allow(item).to receive(:purchase_quotation).and_return(double(organization_id: 1, supplier_id: 2))
      allow(item).to receive(:product).and_return(double(organization_id: 3))
      allow(item).to receive(:supplier_product).and_return(double(organization_id: 1, supplier_id: 9, product_id: 4))
      item.send(:consistent_links)
      expect(item.errors[:product]).not_to be_empty
      expect(item.errors[:supplier_product]).not_to be_empty
    end

    it 'accepts supplier product links for the same supplier, product and organization' do
      item = described_class.new(product_id: 4)
      allow(item).to receive(:purchase_quotation).and_return(double(organization_id: 1, supplier_id: 2))
      allow(item).to receive(:supplier_product).and_return(double(organization_id: 1, supplier_id: 2, product_id: 4))
      item.send(:consistent_links)
      expect(item.errors[:supplier_product]).to be_empty
    end
  end
end
