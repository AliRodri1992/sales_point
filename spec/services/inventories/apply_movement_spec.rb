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
end
