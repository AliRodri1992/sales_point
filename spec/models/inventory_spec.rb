# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventory, type: :model do
  it 'keeps stock independently by branch' do
    organization = create(:organization)
    product = create(:product, organization:)
    first = create(:inventory, organization:, product:, branch: create(:branch, organization:), stock: 12)
    other_branch = create(:branch, organization:, name: 'Sucursal Norte')
    second = create(:inventory, organization:, product:, branch: other_branch, stock: 3)

    expect(first.stock).to eq(12)
    expect(second.stock).to eq(3)
  end

  it 'rejects products belonging to another organization' do
    inventory = build(:inventory, product: create(:product, organization: create(:organization)))
    expect(inventory).not_to be_valid
  end

  it 'rejects invalid maximum and minimum levels' do
    inventory = build(:inventory, min_stock: 20, max_stock: 10)
    expect(inventory).not_to be_valid
  end

  it 'requires a branch and rejects new inventory in a suspended one' do
    item = build(:inventory, branch: nil)
    expect(item).not_to be_valid
    expect(item.errors[:branch]).to be_present

    item.branch = create(:branch, organization: item.organization, operational_state: 'suspended')
    expect(item).not_to be_valid
    expect(item.errors.of_kind?(:branch, :invalid)).to be(true)
  end

  it 'checks branch status again under lock when an inventory holds a stale branch' do
    branch = create(:branch)
    organization = branch.organization
    item = build(:inventory, organization:, branch:)
    actor = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: actor)
    Branches::TransitionStatus.call(branch: Branch.find(branch.id), actor:, to: 'suspended', reason: 'Maintenance')

    expect(branch).to be_active
    expect { item.save! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(item.errors.of_kind?(:branch, :invalid)).to be(true)
    expect(branch.inventories).to be_empty
  end
end
