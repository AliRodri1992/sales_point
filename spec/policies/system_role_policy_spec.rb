# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolePolicy do
  let(:record) { build(:system_role) }

  context 'when the user is a superadministrator' do
    let(:user) { create(:user) }

    before do
      create(:organization_membership, user:)
      create(:user_role, user:, system_role: create(:system_role, :system, code: 'super_admin'))
    end

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

  context 'when the role is a protected administrator' do
    let(:user) { create(:user) }

    before do
      create(:organization_membership, user:)
      create(:user_role, user:, system_role: create(:system_role, :system, code: 'super_admin'))
    end

    it 'allows viewing but forbids deletion or modifying permissions' do
      SystemRole::ADMINISTRATIVE_CODES.each do |code|
        role = build(:system_role, :system, code:)
        policy = described_class.new(user, role)
        expect(policy.show?).to be(true)
        expect(policy.update?).to be(false)
        expect(policy.destroy?).to be(false)
        expect(policy.update_permissions?).to be(false)
      end
    end
  end

  context 'when the user is a regular administrator' do
    let(:user) { create(:user) }

    before do
      create(:organization_membership, user:)
      create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    end

    it 'can view roles but cannot manage global privileges' do
      policy = described_class.new(user, record)
      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.change_status?).to be(false)
      expect(policy.update_permissions?).to be(false)
    end
  end

  context 'when the user is not an administrator' do
    let(:user) { build(:user) }

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

    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
    expect(policy.update_permissions?).to be(false)
  end
end
