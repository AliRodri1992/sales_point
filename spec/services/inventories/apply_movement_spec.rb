# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventories::ApplyMovement do
  def suspend_branch(office)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization: office.organization, user: admin)
    Branches::TransitionStatus.call(
      branch: office, actor: admin, to: 'suspended', reason: 'Maintenance'
    )
  end

  it 'records an adjustment and changes only its branch inventory' do
    inventory = create(:inventory, stock: 15)
    movement = described_class.call(inventory:, quantity: -4, kind: 'adjustment')

    expect(inventory.reload.stock).to eq(11)
    expect(movement).to have_attributes(stock_before: 15, stock_after: 11, quantity: -4)
  end

  it 'rolls back negative stock' do
    inventory = create(:inventory, stock: 1)
    expect do
      described_class.call(inventory:, quantity: -2, kind: 'sale')
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(inventory.reload.stock).to eq(1)
    expect(InventoryMovement.count).to eq(0)
  end

  it 'requires a lot for changes to lot-tracked merchandise' do
    inventory = create(:inventory, stock: 3)
    inventory.product.update!(tracking_mode: :lot)

    expect do
      described_class.call(inventory:, quantity: 2, kind: 'adjustment')
    end.to raise_error(ArgumentError, /requires a lot-specific/)
    expect(inventory.reload.stock).to eq(3)
  end

  it 'rejects a movement linked to a different branch inventory lot' do
    inventory = create(:inventory)
    other = create(:inventory, organization: inventory.organization,
                               product: inventory.product,
                               branch: create(:branch, organization: inventory.organization, name: 'Sucursal Este'))
    lot = other.inventory_lots.create!(
      organization: other.organization, code: 'OTHER-BRANCH-LOT', quantity: 1
    )

    expect do
      described_class.call(inventory:, quantity: 1, kind: 'receipt', inventory_lot: lot)
    end.to raise_error(ArgumentError, /another inventory/)
    expect(inventory.reload.stock).to eq(0)
  end
  it 'blocks sales when the owning organization is inactive' do
    inventory = create(:inventory, stock: 10)
    inventory.organization.update!(status: 'inactive')

    expect do
      described_class.call(inventory:, quantity: -1, kind: 'sale')
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(inventory.reload.stock).to eq(10)
  end

  it 'permits stock reconciliation but blocks inbound transfers while suspended' do
    branch = create(:branch)
    product = create(:product, organization: branch.organization)
    inventory = create(:inventory, branch:, organization: branch.organization,
                                   product:, stock: 5)
    suspend_branch(branch)

    expect do
      described_class.call(inventory:, quantity: 2, kind: 'transfer_in')
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(inventory.reload.stock).to eq(5)

    adjustment = described_class.call(inventory:, quantity: -1, kind: 'adjustment')
    expect(adjustment.kind).to eq('adjustment')
    expect(inventory.reload.stock).to eq(4)
  end

  it 'blocks a sale from a suspended branch without changing stock' do
    office = create(:branch)
    item = create(:product, organization: office.organization)
    inventory = create(:inventory, branch: office, organization: office.organization, product: item, stock: 10)
    suspend_branch(office)

    expect do
      described_class.call(inventory:, quantity: -1, kind: 'sale')
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(inventory.reload.stock).to eq(10)
    expect(inventory.inventory_movements.count).to eq(0)
  end
end
