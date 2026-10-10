require 'rails_helper'

RSpec.describe SupplierPolicy do
  let(:organization) { create(:organization) }
  let(:supplier) { build(:supplier, organization:) }
  let(:user) { create(:user) }

  it 'allows administrators' do
    role = create(:system_role, code: 'administrator', role_type: :system)
    create(:user_role, user:, system_role: role)
    create(:organization_membership, user:, organization:)

    policy = described_class.new(user, supplier)
    expect(policy.index?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
  end

  it 'denies non-administrators' do
    policy = described_class.new(user, supplier)
    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.new?).to be(false)
  end

  it 'denies access when no user is authenticated' do
    policy = described_class.new(nil, supplier)

    expect(policy.index?).to be_nil
    expect(policy.show?).to be_nil
    expect(policy.new?).to be_nil
    expect(policy.create?).to be_nil
    expect(policy.edit?).to be_nil
    expect(policy.update?).to be_nil
    expect(policy.destroy?).to be_nil
  end
end
RSpec.describe SupplierPolicy::Scope do
  let(:scope) { Supplier.all }

  it 'returns no records for a non-administrator' do
    expect(described_class.new(create(:user), scope).resolve).to be_empty
  end

  it 'returns the complete scope for an administrator' do
    admin = create(:user)
    role = create(:system_role, code: 'administrator', role_type: :system)
    create(:user_role, user: admin, system_role: role)
    create(:organization_membership, user: admin, organization: create(:organization))

    expect(described_class.new(admin, scope).resolve).to be_empty
  end

  it 'returns no records when the user is nil' do
    expect(described_class.new(nil, scope).resolve).to be_empty
  end
end
