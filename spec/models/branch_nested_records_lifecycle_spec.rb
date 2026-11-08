# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branch-owned inventory and receipt records', type: :model do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:admin) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:inventory) { create(:inventory, organization:, branch:, stock: 0) }

  before { create(:organization_membership, organization:, user: admin) }

  def close_branch!
    Branches::TransitionStatus.call(
      branch:, actor: admin, to: 'closed', reason: 'End of branch operations'
    )
  end

  it 'blocks new and existing lot modifications after permanent closure' do
    lot = InventoryLot.create!(
      organization:, inventory:, code: 'LOT-CLOSING-001', quantity: 0, status: :available
    )
    close_branch!

    expect(lot.update(quantity: 1)).to be(false)
    expect(lot.errors[:base]).to be_present
    expect(lot.reload.quantity).to eq(0)

    next_lot = InventoryLot.new(
      organization:, inventory:, code: 'LOT-CLOSING-002', quantity: 0
    )
    expect(next_lot).not_to be_valid
    expect(next_lot.errors[:base]).to be_present
  end

  it 'blocks modifications to serial numbers linked to a closed branch' do
    lot = InventoryLot.create!(
      organization:, inventory:, code: 'LOT-SERIAL-CLOSED', quantity: 0, status: :available
    )
    serial = InventorySerial.create!(
      organization:, inventory_lot: lot, serial_number: 'SERIAL-TEST-001', status: :available
    )
    close_branch!

    expect(serial.update(status: :sold)).to be(false)
    expect(serial.errors[:base]).to be_present
    expect(serial.reload).to be_available
  end

  it 'rejects receipt-item writes belonging to a closed branch' do
    close_branch!
    item = GoodsReceiptItem.new(goods_receipt: GoodsReceipt.new(branch:))

    expect(item).not_to be_valid
    expect(item.errors[:base]).to be_present
  end
end
