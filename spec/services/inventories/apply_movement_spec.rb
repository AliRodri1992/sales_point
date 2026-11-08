# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventories::ApplyMovement do
  def suspend_branch(office)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization: office.organization, user: admin)
    Branches::TransitionStatus.call(
      branch: office, actor: admin, to: 'suspended', reason: 'Maintenance'
    )
    admin
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

  it 'requires selecting a lot for untracked products when receipt lots already exist' do
    inventory = create(:inventory, stock: 4)
    lot = InventoryLot.create!(
      inventory:, organization: inventory.organization,
      code: 'UNTRACKED-RECEIPT-LOT', quantity: 4, status: :available
    )

    expect do
      described_class.call(inventory:, quantity: -2, kind: 'adjustment')
    end.to raise_error(ArgumentError, /requires a lot-specific/)
    expect(inventory.reload.stock).to eq(4)

    described_class.call(inventory:, quantity: -2, kind: 'adjustment', inventory_lot: lot)
    expect(inventory.reload.stock).to eq(2)
    expect(lot.reload.quantity).to eq(2)
  end

  it 'updates tracked lot and aggregate stock together for an adjustment' do
    inventory = create(:inventory, stock: 5)
    inventory.product.update!(tracking_mode: 'lot')
    lot = InventoryLot.create!(
      inventory:, organization: inventory.organization,
      code: 'ADJUST-LOT-001', quantity: 5, status: :available
    )

    movement = described_class.call(
      inventory:, quantity: -2, kind: 'adjustment', inventory_lot: lot
    )

    expect(movement.inventory_lot).to eq(lot)
    expect(inventory.reload.stock).to eq(3)
    expect(lot.reload.quantity).to eq(3)
  end

  it 'rejects an adjustment that would make a tracked lot negative' do
    inventory = create(:inventory, stock: 5)
    inventory.product.update!(tracking_mode: 'lot')
    lot = InventoryLot.create!(
      inventory:, organization: inventory.organization,
      code: 'ADJUST-LOT-002', quantity: 1, status: :available
    )

    expect do
      described_class.call(inventory:, quantity: -2, kind: 'adjustment', inventory_lot: lot)
    end.to raise_error(ArgumentError, /Lot quantity cannot become negative/)
    expect(inventory.reload.stock).to eq(5)
    expect(lot.reload.quantity).to eq(1)
  end

  it 'prevents a quarantined lot from being reconciled as available stock' do
    inventory = create(:inventory, stock: 0)
    inventory.product.update!(tracking_mode: 'lot')
    lot = InventoryLot.create!(
      inventory:, organization: inventory.organization,
      code: 'QUARANTINED-LOT', quantity: 2, status: :quarantined
    )

    expect do
      described_class.call(inventory:, quantity: 1, kind: 'adjustment', inventory_lot: lot)
    end.to raise_error(ArgumentError, /Quarantined lots/)
    expect(inventory.reload.stock).to eq(0)
    expect(lot.reload.quantity).to eq(2)
  end

  it 'requires serial-level reconciliation for serialized stock adjustments' do
    inventory = create(:inventory, stock: 1)
    inventory.product.update!(tracking_mode: 'serial')
    lot = InventoryLot.create!(
      inventory:, organization: inventory.organization,
      code: 'SERIAL-RECONCILE', quantity: 1, status: :available
    )

    expect do
      described_class.call(inventory:, quantity: -1, kind: 'adjustment', inventory_lot: lot)
    end.to raise_error(ArgumentError, /serial-level reconciliation/)
    expect(inventory.reload.stock).to eq(1)
    expect(lot.reload.quantity).to eq(1)
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
    admin = suspend_branch(branch)

    expect do
      described_class.call(inventory:, quantity: 2, kind: 'transfer_in')
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(inventory.reload.stock).to eq(5)

    adjustment = described_class.call(inventory:, quantity: -1, kind: 'adjustment', user: admin)
    expect(adjustment.kind).to eq('adjustment')
    expect(inventory.reload.stock).to eq(4)
  end

  it 'rejects unapproved movements and every new stock entry during suspension' do
    inventory = create(:inventory, stock: 8)
    admin = suspend_branch(inventory.branch)

    [
      ['receipt', 2],
      ['transfer_in', 2],
      ['transfer_out', -2],
      ['return', -1],
      ['adjustment', 2]
    ].each do |kind, amount|
      expect do
        described_class.call(inventory:, quantity: amount, kind:, user: admin)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    expect do
      described_class.call(inventory:, quantity: -1, kind: 'adjustment')
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(inventory.reload.stock).to eq(8)
    expect(inventory.inventory_movements.count).to eq(0)
  end

  it 'permits supplier returns only for receipt items recorded before suspension' do
    inventory = create(:inventory, stock: 5)
    admin = suspend_branch(inventory.branch)
    receipt = instance_double(
      GoodsReceipt, id: 17, branch_id: inventory.branch_id, created_at: 3.days.ago
    )
    order_item = instance_double(PurchaseOrderItem, product_id: inventory.product_id)
    receipt_item = instance_double(
      GoodsReceiptItem, goods_receipt: receipt, purchase_order_item: order_item,
                        created_at: 2.days.ago, persisted?: true
    )
    return_record = PurchaseReturnItem.new
    allow(return_record).to receive(:persisted?).and_return(true)
    allow(return_record).to receive(:goods_receipt_item).and_return(receipt_item)
    allow(return_record).to receive(:purchase_return)
      .and_return(instance_double(PurchaseReturn, goods_receipt_id: receipt.id))

    expect(described_class.established_supplier_return?(inventory, return_record)).to be(true)
    expect(
      described_class.suspended_movement?(inventory, 'return', -1, { source: return_record, user: admin })
    ).to be(true)
    expect(
      described_class.suspended_movement?(inventory, 'return', -1, { source: return_record, user: nil })
    ).to be(false)

    allow(receipt_item).to receive(:created_at).and_return(1.hour.from_now)
    expect(described_class.established_supplier_return?(inventory, return_record)).to be(false)
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
