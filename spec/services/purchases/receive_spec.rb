# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Purchases::Receive do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user) }
  let(:order) do
    PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency,
      requested_by: user, freight_amount: 12, insurance_amount: 3
    )
  end
  let(:line) do
    order.purchase_order_items.create!(
      product:, quantity: 10, units_per_package: 10, unit_price: 100,
      discount_percent: 5
    )
  end

  before { order.update!(status: :ordered) }

  def receive(quantity:, accepted: quantity, damaged: 0, token: 'delivery-1', extras: {})
    described_class.call(
      order:, user:, idempotency_key: token,
      entries: [{
        purchase_order_item_id: line.id, delivered_quantity: quantity,
        accepted_quantity: accepted, damaged_quantity: damaged
      }.merge(extras)]
    )
  end

  it 'creates a partial receipt and a transactional inventory movement' do
    receipt = receive(quantity: 6, accepted: 5, damaged: 1)
    inventory = Inventory.find_by!(branch:, product:)

    expect(receipt.goods_receipt_items.first).to have_attributes(
      accepted_quantity: 5, damaged_quantity: 1, delivered_quantity: 6
    )
    expect(inventory.stock).to eq(5)
    expect(inventory.inventory_movements.first).to have_attributes(
      kind: 'receipt', stock_before: 0, stock_after: 5
    )
    expect(order.reload).to be_partially_received
    expect(receipt.goods_receipt_items.first.purchase_cost_allocation).to be_present
  end

  it 'rejects an idempotency key already used by another order' do
    first = receive(quantity: 2)
    other_order = PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency, requested_by: user, status: :ordered
    )
    other_order.purchase_order_items.create!(
      product:, quantity: 10, units_per_package: 1, unit_price: 10
    )

    expect do
      described_class.call(
        order: other_order, user:, idempotency_key: first.idempotency_key,
        entries: [{ purchase_order_item_id: other_order.purchase_order_items.first.id,
                    delivered_quantity: 1, accepted_quantity: 1, damaged_quantity: 0 }]
      )
    end.to raise_error(ArgumentError, /different purchase order/)
    expect(other_order.goods_receipts.count).to eq(0)
  end

  it 'marks the purchase order received when the accepted quantity completes the order' do
    receive(quantity: 6, token: 'delivery-1')
    receive(quantity: 4, token: 'delivery-2')

    expect(order.reload).to be_received
    expect(Inventory.find_by!(branch:, product:).stock).to eq(10)
    expect(order.goods_receipts.count).to eq(2)
  end

  it 'returns the same receipt when its idempotency key repeats' do
    first = receive(quantity: 4)
    again = receive(quantity: 4)

    expect(again.id).to eq(first.id)
    expect(order.goods_receipts.count).to eq(1)
    expect(Inventory.find_by!(branch:, product:).stock).to eq(4)
  end

  it 'rolls back the receipt and stock when quantities exceed the order' do
    expect { receive(quantity: 11) }.to raise_error(ArgumentError, /over-receive/)
    expect(GoodsReceipt.count).to eq(0)
    expect(Inventory.where(branch:, product:).count).to eq(0)
  end

  it 'rejects delivery quantities that do not account for accepted and damaged units' do
    expect { receive(quantity: 3, accepted: 3, damaged: 2) }
      .to raise_error(ArgumentError, /exceed delivery/)
    expect(GoodsReceipt.count).to eq(0)
  end

  it 'requires the lot code for a lot-tracked product' do
    product.update!(tracking_mode: 'lot')
    expect { receive(quantity: 2) }.to raise_error(ArgumentError, /Lot number/)
    expect(GoodsReceipt.count).to eq(0)
  end

  it 'records a lot and expiration for traceable stock' do
    product.update!(tracking_mode: 'lot')
    receipt = receive(quantity: 2, extras: { lot_code: 'LOT-2026', expires_on: Date.tomorrow })

    lot = receipt.goods_receipt_items.first.inventory_lots.first
    expect(lot.quantity).to eq(2)
    expect(lot.expires_on).to eq(Date.tomorrow)
  end

  it 'rejects expired product receipts' do
    expect do
      receive(quantity: 2, extras: { expires_on: Date.yesterday })
    end.to raise_error(ArgumentError, /Expired merchandise/)
  end

  it 'requires one unique serial number for every accepted unit' do
    product.update!(tracking_mode: 'serial')
    expect do
      receive(quantity: 2, extras: { serial_numbers: %w[S-1 S-1] })
    end.to raise_error(ArgumentError, /Serial count/)
    expect(GoodsReceipt.count).to eq(0)
  end

  it 'stores valid serial numbers for a serial-tracked delivery' do
    product.update!(tracking_mode: 'serial')
    receipt = receive(quantity: 2, extras: { serial_numbers: %w[S-1 S-2] })

    expect(receipt.goods_receipt_items.first.inventory_lots.first.inventory_serials.pluck(:serial_number))
      .to match_array(%w[S-1 S-2])
  end
  it 'records damaged-only deliveries in quarantine without increasing available stock' do
    product.update!(tracking_mode: 'lot')
    receipt = receive(quantity: 3, accepted: 0, damaged: 3, extras: { lot_code: 'DAM-01' })
    lot = receipt.goods_receipt_items.first.inventory_lots.first

    expect(lot).to be_quarantined
    expect(lot.quantity).to eq(3)
    expect(lot.inventory.reload.stock).to eq(0)
    expect(lot.inventory.inventory_movements.count).to eq(0)
  end

  it 'quarantines damaged serial numbers independently of accepted merchandise' do
    product.update!(tracking_mode: 'serial')
    receipt = receive(
      quantity: 3, accepted: 2, damaged: 1,
      extras: { serial_numbers: %w[OK1 OK2], damaged_serial_numbers: %w[BAD1] }
    )
    lots = receipt.goods_receipt_items.first.inventory_lots
    expect(lots.available.sum(:quantity)).to eq(2)
    expect(lots.quarantined.sum(:quantity)).to eq(1)
    expect(lots.flat_map(&:inventory_serials).map(&:serial_number)).to match_array(%w[OK1 OK2 BAD1])
    expect(Inventory.find_by!(branch:, product:).stock).to eq(2)
  end


end
