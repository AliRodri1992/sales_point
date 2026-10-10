# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryPolicy do
  let(:user) { build(:user) }
  let(:category) { build(:category) }
  let(:policy) { described_class.new(user, category) }

  before do
    allow(user).to receive(:permission?).with('categories.access').and_return(allowed)
  end

  context 'when the user has category access' do
    let(:allowed) { true }

    it 'allows category actions' do
      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.destroy?).to be(true)
    end
  end

  context 'when the user does not have category access' do
    let(:allowed) { false }

    it 'denies category actions' do
      expect(policy.index?).to be(false)
      expect(policy.show?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.destroy?).to be(false)
    end
  end

  describe CategoryPolicy::Scope do
    it 'returns the supplied scope' do
      records = Category.all

      expect(described_class.new(user, records).resolve).to equal(records)
    end
  end
end
