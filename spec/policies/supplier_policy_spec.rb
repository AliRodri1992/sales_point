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

    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.new?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.edit?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
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

RSpec.describe 'SupplierPolicy dossier authorization boundaries' do
  let(:organization) { create(:organization) }
  let(:supplier) { build(:supplier, organization:) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, user:, organization:)
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)
  end

  it 'allows document management to imply document viewing but not supplier editing' do
    allow(user).to receive(:permission?).with('suppliers.documents.manage').and_return(true)
    policy = SupplierPolicy.new(user, supplier)

    expect(policy.index?).to be(true)
    expect(policy.show?).to be(true)
    expect(policy.view_documents?).to be(true)
    expect(policy.manage_documents?).to be(true)
    expect(policy.view_fiscal?).to be(false)
    expect(policy.edit?).to be(false)
  end

  it 'allows fiscal management to imply fiscal viewing but not contacts' do
    allow(user).to receive(:permission?).with('suppliers.fiscal.manage').and_return(true)
    policy = SupplierPolicy.new(user, supplier)

    expect(policy.view_fiscal?).to be(true)
    expect(policy.manage_fiscal?).to be(true)
    expect(policy.view_contacts?).to be(false)
    expect(policy.manage_contacts?).to be(false)
  end

  it 'allows address and schedule management only for their own dossier sections' do
    allow(user).to receive(:permission?).with('suppliers.addresses.manage').and_return(true)
    allow(user).to receive(:permission?).with('suppliers.schedules.manage').and_return(true)
    policy = SupplierPolicy.new(user, supplier)

    expect(policy.view_addresses?).to be(true)
    expect(policy.manage_addresses?).to be(true)
    expect(policy.view_schedules?).to be(true)
    expect(policy.manage_schedules?).to be(true)
    expect(policy.view_products?).to be(false)
  end

  it 'separates product management from commercial and banking access' do
    allow(user).to receive(:permission?).with('suppliers.products.manage').and_return(true)
    policy = SupplierPolicy.new(user, supplier)

    expect(policy.view_products?).to be(true)
    expect(policy.manage_products?).to be(true)
    expect(policy.view_commercial?).to be(false)
    expect(policy.manage_commercial?).to be(false)
  end

  it 'does not accept an inactive membership even with supplier permissions' do
    user.organization_memberships.update_all(status: :inactive)
    allow(user).to receive(:permission?).with('suppliers.view').and_return(true)
    policy = SupplierPolicy.new(user, supplier)

    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.view_general?).to be(false)
    expect(policy.export?).to be(false)
  end

  it 'does not disclose a supplier from another organization' do
    foreign_supplier = build(:supplier, organization: create(:organization))
    allow(user).to receive(:permission?).with('suppliers.view').and_return(true)
    policy = SupplierPolicy.new(user, foreign_supplier)

    expect(policy.show?).to be(false)
    expect(policy.view_general?).to be(false)
    expect(policy.view_documents?).to be(false)
  end

  it 'requires create permission independently of list and export permissions' do
    allow(user).to receive(:permission?).with('suppliers.export').and_return(true)
    policy = SupplierPolicy.new(user, supplier)

    expect(policy.index?).to be(true)
    expect(policy.export?).to be(true)
    expect(policy.new?).to be(false)
    expect(policy.create?).to be(false)
  end
end
