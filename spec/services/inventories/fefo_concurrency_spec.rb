# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Concurrent FEFO inventory allocation', :concurrent_db do
  it 'serializes competing lot allocations in branch-inventory-lot order' do
    organization = create(:organization)
    branch = create(:branch, organization:)
    product = create(:product, organization:, tracking_mode: 'lot')
    inventory = create(:inventory, branch:, organization:, product:, stock: 5)
    lot = InventoryLot.create!(
      inventory:, organization:, code: 'FEFO-COMPETING', quantity: 5,
      status: :available, expires_on: Date.tomorrow
    )
    user = create(:user)
    barrier = Queue.new

    attempts = [2, 3].map do |quantity|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          Inventories::FefoAllocator.call(
            inventory: Inventory.find(inventory.id), quantity:, user: User.find(user.id)
          )
          :allocated
        end
      end
    end

    2.times { barrier << true }
    expect(attempts.map(&:value)).to eq(%i[allocated allocated])
    expect(inventory.reload.stock).to eq(0)
    expect(lot.reload.quantity).to eq(0)
    expect(inventory.inventory_movements.where(kind: 'sale').sum(:quantity)).to eq(-5)
    expect(inventory.inventory_movements.where(kind: 'sale').count).to eq(2)
  end
end
