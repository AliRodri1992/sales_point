# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurchaseOrderPolicy do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:order) do
    PurchaseOrder.create!(organization:, branch:, supplier:, currency: supplier.currency, requested_by: user)
  end

  before { create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator')) }

  it 'rejects access without an active organization membership' do
    expect(described_class.new(user, order).show?).to be(false)
    expect(described_class::Scope.new(user, PurchaseOrder.all).resolve).not_to include(order)
  end

  it 'accepts access within an active membership' do
    create(:organization_membership, user:, organization:)
    expect(described_class.new(user, order).show?).to be(true)
    expect(described_class::Scope.new(user, PurchaseOrder.all).resolve).to include(order)
  end

  it 'does not grant access to purchases from another organization' do
    create(:organization_membership, user:, organization: create(:organization))
    expect(described_class.new(user, order).approve?).to be(false)
    expect(described_class::Scope.new(user, PurchaseOrder.all).resolve).not_to include(order)
  end
end
