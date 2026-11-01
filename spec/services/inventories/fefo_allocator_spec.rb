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

  it 'consumes the soonest-expiring lot first' do
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
end
