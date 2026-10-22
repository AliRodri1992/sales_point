# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierPolicy do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, user:, organization:)
  end

  it 'denies contacts management without its explicit permission' do
    expect(described_class.new(user, supplier).manage_contacts?).to be(false)
  end

  it 'allows scoped contacts management without granting fiscal data access' do
    role = create(:system_role, role_type: :system, status: :active)
    permission = Permission.create!(
      code: 'suppliers.contacts.manage', name: 'Manage contacts',
      module_name: 'Proveedores', status: :active
    )
    role.permissions << permission
    create(:user_role, user:, system_role: role)

    policy = described_class.new(user, supplier)
    expect(policy.manage_contacts?).to be(true)
    expect(policy.manage_fiscal?).to be(false)
  end

  it 'grants dossier access only to the authorized section and scopes the supplier' do
    allow(user).to receive(:permission?) { |permission| permission == 'suppliers.contacts.manage' }
    policy = described_class.new(user, supplier)

    expect(policy.show?).to be(true)
    expect(policy.view_contacts?).to be(true)
    expect(policy.view_fiscal?).to be(false)
    expect(policy.view_documents?).to be(false)
    expect(described_class::Scope.new(user, Supplier.all).resolve).to include(supplier)
  end

  it 'permits listing suppliers with only a contacts-management privilege' do
    allow(user).to receive(:permission?) { |permission| permission == 'suppliers.contacts.manage' }

    expect(described_class.new(user, Supplier).index?).to be(true)
    expect(described_class.new(user, supplier).show?).to be(true)
  end

  it 'allows bank account management with the corresponding finance permission only' do
    allow(user).to receive(:permission?) { |code| code == 'accounts_payable.banks.manage' }

    expect(described_class.new(user, supplier).show?).to be(true)
    expect(described_class.new(user, supplier).view_fiscal?).to be(false)
    expect(described_class::Scope.new(user, Supplier.all).resolve).to include(supplier)
  end

  it 'allows export-only and create-only users to scope their organization' do
    %w[suppliers.export suppliers.create].each do |permission|
      allow(user).to receive(:permission?) { |code| code == permission }
      expect(described_class::Scope.new(user, Supplier.all).resolve).to include(supplier)
      expect(described_class.new(user, Supplier).index?).to be(true)
    end
  end

  it 'rejects an unrelated organization even with the permission' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    allow(user).to receive(:permission?).with('suppliers.contacts.manage').and_return(true)

    expect(described_class.new(user, foreign_supplier).manage_contacts?).to be(false)
  end
end
