# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolePolicy do
  let(:record) { build(:system_role) }

  context 'when the user is an administrator' do
    let(:user) { build(:user) }

    before { allow(user).to receive(:admin?).and_return(true) }

    it 'allows all system role actions' do
      policy = described_class.new(user, record)

      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.destroy?).to be(true)
      expect(policy.update_permissions?).to be(true)
    end
  end

  context 'when the user is not an administrator' do
    let(:user) { build(:user) }

    before { allow(user).to receive(:admin?).and_return(false) }

    it 'denies all system role actions' do
      policy = described_class.new(user, record)

      expect(policy.index?).to be(false)
      expect(policy.show?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.destroy?).to be(false)
      expect(policy.update_permissions?).to be(false)
    end
  end

  it 'denies actions when no user is present' do
    policy = described_class.new(nil, record)

    expect(policy.index?).to be_nil
    expect(policy.show?).to be_nil
    expect(policy.create?).to be_nil
    expect(policy.update?).to be_nil
    expect(policy.destroy?).to be_nil
    expect(policy.update_permissions?).to be_nil
  end
end
