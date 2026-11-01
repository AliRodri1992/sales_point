# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(user, record) }

  let(:user) { nil }
  let(:record) { Object.new }

  it 'stores the user and record' do
    expect(policy.user).to equal(user)
    expect(policy.record).to equal(record)
  end

  it 'denies actions by default' do
    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.new?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.edit?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  describe ApplicationPolicy::Scope do
    subject(:scope) { described_class.new(user, records) }

    let(:user) { nil }
    let(:records) { [] }

    it 'stores the user and scope' do
      expect(scope.user).to equal(user)
      expect(scope.scope).to equal(records)
    end

    it 'requires subclasses to implement resolve' do
      expect { scope.resolve }.to raise_error(
        NotImplementedError,
        'ApplicationPolicy::Scope must implement #resolve'
      )
    end
  end
end
