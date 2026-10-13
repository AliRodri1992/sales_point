# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventories::ApplyMovement do
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

end
