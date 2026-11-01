# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Financial and procurement policy organization scope', type: :policy do
  def member(user, exists:)
    membership = double
    allow(membership).to receive_messages(where: membership, joins: membership, merge: membership,
                                          exists?: exists, select: membership)
    allow(user).to receive(:organization_memberships).and_return(membership)
  end

  [FinancialPolicy, PurchaseOrderPolicy, SupplierBankAccountPolicy].each do |klass|
    describe klass.name do
      let(:record) { double(organization_id: 1, draft?: true) }
      let(:user) { double(admin?: false, permission?: true) }

      it 'rejects a missing user or organization' do
        expect(klass.new(nil, record).index?).to be(false)
        expect(klass.new(user, double(organization_id: nil)).index?).to be(false)
      end

      it 'rejects users who do not have an active organization membership' do
        member(user, exists: false)
        expect(klass.new(user, record).index?).to be(false)
      end

      it 'allows permissions with active organization membership' do
        member(user, exists: true)
        expect(klass.new(user, record).index?).to be(true)
      end

      it 'denies missing permissions even with an active membership' do
        member(user, exists: true)
        allow(user).to receive(:permission?).and_return(false)
        expect(klass.new(user, record).index?).to be(false)
      end
    end
  end

  describe FinancialPolicy::Scope do
    it 'returns an empty scope without any user' do
      relation = double(none: :empty)
      expect(described_class.new(nil, relation).resolve).to eq(:empty)
    end

    it 'returns an empty scope without read permission' do
      relation = double(none: :empty)
      user = double(admin?: false, permission?: false)
      expect(described_class.new(user, relation).resolve).to eq(:empty)
    end

    it 'filters documents using only authorized organization memberships' do
      relation = double
      allow(relation).to receive(:where).and_return(:authorized)
      user = double(admin?: true)
      member(user, exists: true)
      expect(described_class.new(user, relation).resolve).to eq(:authorized)
    end
  end
end
