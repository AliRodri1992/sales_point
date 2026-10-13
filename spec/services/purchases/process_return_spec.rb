# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Purchases::ProcessReturn do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user) }
  let(:order) do
    PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency,
      requested_by: user, status: :ordered
    )
  end
  let(:line) do
    order.purchase_order_items.create!(
      product:, quantity: 10, units_per_package: 10, unit_price: 100
    )
  end
  let(:receipt) do
    Purchases::Receive.call(
      order:, user:, idempotency_key: 'return-origin',
      entries: [{ purchase_order_item_id: line.id, delivered_quantity: 5,
                  accepted_quantity: 5, damaged_quantity: 0 }]
    )
  end
  let(:receipt_item) { receipt.goods_receipt_items.first }

  def return_document(quantity:)
    purchase_return = PurchaseReturn.create!(
      organization:, goods_receipt: receipt, requested_by: user, reason: :damaged
    )
    purchase_return.purchase_return_items.create!(goods_receipt_item: receipt_item, quantity:)
    purchase_return
  end

  it 'subtracts returned goods and preserves the movement source' do
    purchase_return = return_document(quantity: 2)
    lot = receipt_item.inventory_lots.first

    described_class.call(purchase_return:, user:)

    expect(purchase_return.reload).to be_processed
    expect(lot.reload.quantity).to eq(3)
    expect(lot.inventory.reload.stock).to eq(3)
    expect(InventoryMovement.last).to have_attributes(
      kind: 'return', quantity: -2, source: purchase_return.purchase_return_items.first
    )
  end

  it 'rejects duplicate processing of the same return' do
    purchase_return = return_document(quantity: 2)
    described_class.call(purchase_return:, user:)

    expect do
      described_class.call(purchase_return:, user:)
    end.to raise_error(ArgumentError, /already finalized/)
    expect(receipt_item.inventory_lots.first.inventory.reload.stock).to eq(3)
  end

  it 'does not return more than was accepted' do
    purchase_return = return_document(quantity: 6)

    expect do
      described_class.call(purchase_return:, user:)
    end.to raise_error(ArgumentError, /exceeds accepted/)
    expect(receipt_item.inventory_lots.first.inventory.reload.stock).to eq(5)
    expect(purchase_return.reload).to be_draft
  end

  it 'does not permit returning merchandise that has already been sold' do
    purchase_return = return_document(quantity: 5)
    inventory = receipt_item.inventory_lots.first.inventory
    Inventories::FefoAllocator.call(inventory:, quantity: 3, user:)

    expect do
      described_class.call(purchase_return:, user:)
    end.to raise_error(ArgumentError, /Not enough stock|insufficient/)
    expect(inventory.reload.stock).to eq(2)
    expect(purchase_return.reload).to be_draft
  end

  it 'permits returning an originally accepted lot that expired after receipt' do
    purchase_return = return_document(quantity: 1)
    receipt_item.inventory_lots.first.update!(expires_on: Date.yesterday)

    described_class.call(purchase_return:, user:)

    expect(purchase_return.reload).to be_processed
    expect(receipt_item.inventory_lots.first.inventory.reload.stock).to eq(4)
  end

  it 'prevents separate return documents exceeding the original receipt' do
    first = return_document(quantity: 3)
    described_class.call(purchase_return: first, user:)
    second = return_document(quantity: 3)

    expect do
      described_class.call(purchase_return: second, user:)
    end.to raise_error(ArgumentError, /exceeds accepted/)
    expect(receipt_item.inventory_lots.first.inventory.reload.stock).to eq(2)
  end

  it 'returns quarantined damaged merchandise without subtracting available inventory' do
    receipt = Purchases::Receive.call(
      order: another_order, user:, idempotency_key: 'damaged-return-source',
      entries: [{ purchase_order_item_id: another_line.id, delivered_quantity: 3,
                  accepted_quantity: 1, damaged_quantity: 2, lot_code: 'DAMAGE-A' }]
    )
    damaged_item = receipt.goods_receipt_items.first
    purchase_return = PurchaseReturn.create!(
      organization:, goods_receipt: receipt, requested_by: user, reason: :damaged
    )
    purchase_return.purchase_return_items.create!(
      goods_receipt_item: damaged_item, quantity: 2, stock_disposition: :quarantined
    )

    described_class.call(purchase_return:, user:)

    expect(purchase_return.reload).to be_processed
    expect(damaged_item.inventory_lots.quarantined.sum(:quantity)).to eq(0)
    expect(damaged_item.inventory_lots.depleted.sum(:quantity)).to eq(0)
    expect(Inventory.find_by!(branch:, product:).stock).to eq(1)
  end

  it 'rejects quarantined returns in excess of damaged received units' do
    source = Purchases::Receive.call(
      order: another_order, user:, idempotency_key: 'quarantine-overreturn',
      entries: [{ purchase_order_item_id: another_line.id, delivered_quantity: 3,
                  accepted_quantity: 1, damaged_quantity: 2 }]
    )
    line = source.goods_receipt_items.first
    purchase_return = PurchaseReturn.create!(
      organization:, goods_receipt: source, requested_by: user, reason: :damaged
    )
    purchase_return.purchase_return_items.create!(
      goods_receipt_item: line, quantity: 3, stock_disposition: :quarantined
    )

    expect do
      described_class.call(purchase_return:, user:)
    end.to raise_error(ArgumentError, /exceeds damaged/)
    expect(line.inventory_lots.quarantined.sum(:quantity)).to eq(2)
    expect(line.inventory_lots.first.inventory.reload.stock).to eq(1)
  end

  it 'ignores unselected return lines but retains selected items' do
    purchase_return = PurchaseReturn.create!(
      organization:, goods_receipt: receipt, requested_by: user,
      purchase_return_items_attributes: [
        { goods_receipt_item_id: receipt_item.id, quantity: '' },
        { goods_receipt_item_id: receipt_item.id, quantity: 1 }
      ]
    )
    expect(purchase_return.purchase_return_items.size).to eq(1)
    described_class.call(purchase_return:, user:)
    expect(purchase_return.reload).to be_processed
  end

  def another_order
    @another_order ||= PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency,
      requested_by: user, status: :ordered
    )
  end

  def another_line
    @another_line ||= another_order.purchase_order_items.create!(
      product:, quantity: 5, units_per_package: 5, unit_price: 50
    )
  end
end
