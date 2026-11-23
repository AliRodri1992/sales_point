# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventories::FefoAllocator do
  let(:inventory) { create(:inventory, stock: 5) }
  let(:user) { create(:user) }
  let!(:later) do
    InventoryLot.create!(
      organization: inventory.organization, inventory:, code: 'LOT-LATER',
      quantity: 3, expires_on: Date.current + 14.days, status: :available
    )
  end
  let!(:earlier) do
    InventoryLot.create!(
      organization: inventory.organization, inventory:, code: 'LOT-EARLY',
      quantity: 2, expires_on: Date.tomorrow, status: :available
    )
  end

  it 'rolls back lot changes if its branch has been suspended' do
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization: inventory.organization, user: admin)
    Branches::TransitionStatus.call(
      branch: inventory.branch, actor: admin, to: 'suspended', reason: 'Maintenance'
    )

    expect do
      described_class.call(inventory:, quantity: 1, user:)
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(inventory.reload.stock).to eq(5)
    expect(earlier.reload.quantity).to eq(2)
    expect(later.reload.quantity).to eq(3)
  end

  it 'allocates from the earliest expiring lot first' do
    described_class.call(inventory:, quantity: 1, user:)

    expect(earlier.reload.quantity).to eq(1)
    expect(later.reload.quantity).to eq(3)
    expect(inventory.reload.stock).to eq(4)
    expect(InventoryMovement.last.inventory_lot).to eq(earlier)
  end

  it 'continues into later lots when the earlier lot is depleted' do
    described_class.call(inventory:, quantity: 4, user:)

    expect(earlier.reload.quantity).to eq(0)
    expect(later.reload.quantity).to eq(1)
    expect(inventory.reload.stock).to eq(1)
    expect(inventory.inventory_movements.count).to eq(2)
  end

  it 'rejects selling more stock than is available' do
    expect do
      described_class.call(inventory:, quantity: 6, user:)
    end.to raise_error(ArgumentError, /Insufficient inventory/)
    expect(inventory.reload.stock).to eq(5)
  end

  it 'does not allocate expired lots' do
    earlier.update!(expires_on: Date.yesterday)
    expect do
      described_class.call(inventory:, quantity: 4, user:)
    end.to raise_error(ArgumentError, /No unexpired stock/)
    expect(inventory.reload.stock).to eq(5)
  end

  it 'refuses an explicitly selected expired lot without deducting stock' do
    earlier.update!(expires_on: Date.yesterday)
    expect do
      described_class.consume_lot!(inventory:, lot: earlier, quantity: 1, user:)
    end.to raise_error(ArgumentError, /Lot is not available/)
    expect(earlier.reload.quantity).to eq(2)
    expect(inventory.reload.stock).to eq(5)
    expect(inventory.inventory_movements).to be_empty
  end

  context 'with a serialized product' do
    let(:product) { create(:product, tracking_mode: 'serial') }
    let(:inventory) { create(:inventory, organization: product.organization, product:, stock: 5) }

    it 'sells the allocated serial and keeps the other serial available' do
      first, second = %w[SERIAL-1 SERIAL-2].map do |number|
        earlier.inventory_serials.create!(organization: inventory.organization, serial_number: number)
      end

      described_class.call(inventory:, quantity: 1, user:)

      expect(first.reload).to be_sold
      expect(second.reload).to be_available
      expect(earlier.reload.quantity).to eq(1)
      expect(inventory.reload.stock).to eq(4)
    end
  end
end
