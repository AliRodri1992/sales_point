# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchasing and supplier banking authorization decisions', type: :policy do
  [FinancialPolicy, PurchaseOrderPolicy, SupplierBankAccountPolicy].each do |policy_class|
    context policy_class.name do
      let(:user) { double(admin?: false, permission?: false) }
      let(:record) { double(organization_id: 1, draft?: true) }
      let(:policy) { policy_class.new(user, record) }

      it 'rejects actions when there is no authorized organizational membership' do
        allow(policy).to receive(:organization_access?).and_return(false)
        expect(policy.index?).to be(false)
        expect(policy.create?).to be(false)
      end

      it 'allows index and creation for an authorized system administrator' do
        allow(user).to receive(:admin?).and_return(true)
        allow(policy).to receive(:organization_access?).and_return(true)
        expect(policy.index?).to be(true)
        expect(policy.create?).to be(true)
      end

      it 'requires module-specific grants for nonadministrators' do
        allow(policy).to receive(:organization_access?).and_return(true)
        expect(policy.index?).to be(false)
        allow(user).to receive(:permission?).and_return(true)
        expect(policy.index?).to be(true)
      end
    end
  end

  describe FinancialPolicy do
    it 'permits draft invoice editing but blocks posted invoices' do
      user = double(admin?: true)
      record = double(organization_id: 1, draft?: true)
      policy = described_class.new(user, record)
      allow(policy).to receive(:organization_access?).and_return(true)
      expect(policy.edit?).to be(true)
      allow(record).to receive(:draft?).and_return(false)
      expect(policy.edit?).to be(false)
    end
  end

  describe PurchaseOrderPolicy do
    it 'denies editing an approved order' do
      policy = described_class.new(double(admin?: true), double(organization_id: 1, draft?: false))
      allow(policy).to receive(:organization_access?).and_return(true)
      expect(policy.edit?).to be(false)
    end
  end
end
