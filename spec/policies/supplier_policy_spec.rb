require 'rails_helper'

RSpec.describe SupplierPolicy do
  let(:supplier) { build(:supplier) }
  let(:user) { create(:user) }

  it 'allows administrators' do
    role = create(:system_role, code: 'administrator', role_type: :system)
    create(:user_role, user:, system_role: role)

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
end
