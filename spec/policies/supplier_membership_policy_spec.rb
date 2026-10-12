# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:role) { create(:system_role, :system, code: 'administrator') }

  before do
    create(:user_role, user:, system_role: role)
  end

  it 'rejects inactive organization memberships' do
    create(:organization_membership, user:, organization:, status: :inactive)

    expect(described_class.new(user, supplier).show?).to be(false)
    expect(described_class::Scope.new(user, Supplier.all).resolve).not_to include(supplier)
  end

  it 'rejects suppliers of unrelated organizations' do
    create(:organization_membership, user:, organization:)

    foreign_supplier = create(:supplier, organization: create(:organization))
    expect(described_class.new(user, foreign_supplier).show?).to be(false)
    expect(described_class::Scope.new(user, Supplier.all).resolve).not_to include(foreign_supplier)
  end

  it 'allows an active membership to access its own supplier' do
    create(:organization_membership, user:, organization:)

    expect(described_class.new(user, supplier).show?).to be(true)
    expect(described_class::Scope.new(user, Supplier.all).resolve).to include(supplier)
  end
end
