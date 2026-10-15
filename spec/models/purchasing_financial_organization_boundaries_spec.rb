# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organization-bound purchasing and financial records', type: :model do
  [
    [PurchaseReturn, :consistent_organization, :goods_receipt],
    [PurchaseApproval, :consistent_organization, :purchase_order]
  ].each do |klass, validator, association|
    context klass.name do
      it 'skips the relation check when no related record is present' do
        record = klass.new(organization_id: 1)
        record.send(validator)
        expect(record.errors[association]).to be_empty
      end

      it 'accepts a related record belonging to the organization' do
        record = klass.new(organization_id: 1)
        allow(record).to receive(association).and_return(double(organization_id: 1))
        record.send(validator)
        expect(record.errors[association]).to be_empty
      end

      it 'rejects a related record from a different organization' do
        record = klass.new(organization_id: 1)
        allow(record).to receive(association).and_return(double(organization_id: 2))
        record.send(validator)
        expect(record.errors[association]).not_to be_empty
      end
    end
  end

  describe PurchaseCostAllocation do
    it 'rejects cross-organization receipt costs and accepts matching organizations' do
      record = described_class.new(organization_id: 1)
      receipt = double(organization_id: 2)
      allow(record).to receive(:goods_receipt_item).and_return(double(goods_receipt: receipt))
      record.send(:consistent_organization)
      expect(record.errors[:goods_receipt_item]).not_to be_empty

      allow(receipt).to receive(:organization_id).and_return(1)
      record.errors.clear
      record.send(:consistent_organization)
      expect(record.errors[:goods_receipt_item]).to be_empty
    end

    it 'skips comparison without a receipt item' do
      record = described_class.new(organization_id: 1)
      record.send(:consistent_organization)
      expect(record.errors[:goods_receipt_item]).to be_empty
    end
  end

  describe PurchaseRequestItem do
    it 'ignores missing associations' do
      record = described_class.new
      record.send(:product_matches_organization)
      expect(record.errors[:product]).to be_empty
    end

    it 'accepts a matching product and rejects an external product' do
      record = described_class.new
      allow(record).to receive(:purchase_request).and_return(double(organization_id: 1))
      allow(record).to receive(:product).and_return(double(organization_id: 1))
      record.send(:product_matches_organization)
      expect(record.errors[:product]).to be_empty

      allow(record).to receive(:product).and_return(double(organization_id: 2))
      record.send(:product_matches_organization)
      expect(record.errors[:product]).not_to be_empty
    end
  end

  describe PurchaseRequest do
    it 'rejects a foreign branch and accepts a matching branch' do
      record = described_class.new(organization_id: 1)
      allow(record).to receive(:branch).and_return(double(organization_id: 2))
      record.send(:branch_belongs_to_organization)
      expect(record.errors[:branch]).not_to be_empty

      record.errors.clear
      allow(record).to receive(:branch).and_return(double(organization_id: 1))
      record.send(:branch_belongs_to_organization)
      expect(record.errors[:branch]).to be_empty
    end

    it 'rejects products from other organizations and accepts the same organization' do
      record = described_class.new(organization_id: 1)
      allow(record).to receive(:purchase_request_items).and_return([double(product: double(organization_id: 2))])
      record.send(:products_belong_to_organization)
      expect(record.errors[:purchase_request_items]).not_to be_empty

      record.errors.clear
      allow(record).to receive(:purchase_request_items).and_return([double(product: double(organization_id: 1))])
      record.send(:products_belong_to_organization)
      expect(record.errors[:purchase_request_items]).to be_empty
    end
  end

  [SupplierPaymentAllocation, SupplierCreditAllocation].each do |klass|
    describe klass.name do
      let(:association) { klass == SupplierPaymentAllocation ? :supplier_payment : :supplier_credit_note }
      let(:record) { klass.new(organization_id: 1) }
      let(:payable) { double(organization_id: 1, supplier_id: 2) }

      it 'skips matching when the payment or credit note is absent' do
        allow(record).to receive(:account_payable).and_return(payable)
        record.send(:matching_organization)
        expect(record.errors[:account_payable]).to be_empty
      end

      it 'accepts matching organization and supplier' do
        allow(record).to receive(association).and_return(double(organization_id: 1, supplier_id: 2))
        allow(record).to receive(:account_payable).and_return(payable)
        record.send(:matching_organization)
        expect(record.errors[:account_payable]).to be_empty
      end

      it 'rejects a different organization' do
        allow(record).to receive(association).and_return(double(organization_id: 3, supplier_id: 2))
        allow(record).to receive(:account_payable).and_return(payable)
        record.send(:matching_organization)
        expect(record.errors[:account_payable]).not_to be_empty
      end

      it 'rejects a different supplier within the same organization' do
        allow(record).to receive(association).and_return(double(organization_id: 1, supplier_id: 3))
        allow(record).to receive(:account_payable).and_return(payable)
        record.send(:matching_organization)
        expect(record.errors[:account_payable]).not_to be_empty
      end
    end
  end
end
