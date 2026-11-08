# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryLot, type: :model do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user) }

  let(:receipt_item) do
    order = PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency,
      requested_by: user, status: :ordered
    )
    line = order.purchase_order_items.create!(
      product:, quantity: 3, units_per_package: 3, unit_price: 50
    )
    receipt = Purchases::Receive.call(
      order:, user:, idempotency_key: 'lot-ownership-check',
      entries: [{ purchase_order_item_id: line.id, delivered_quantity: 3,
                  accepted_quantity: 3, damaged_quantity: 0 }]
    )
    receipt.goods_receipt_items.first
  end

  it 'accepts a receipt lot linked to the same organization, branch and product' do
    inventory = receipt_item.inventory_lots.first.inventory

    lot = described_class.new(
      organization:, inventory:, goods_receipt_item: receipt_item,
      code: 'MATCHED-RECEIPT-LOT', quantity: 0
    )

    expect(lot).to be_valid
  end

  it 'rejects a receipt item belonging to another branch of the same organization' do
    other_branch = create(:branch, organization:, name: 'Other office')
    inventory = create(:inventory, organization:, branch: other_branch, product:)

    lot = described_class.new(
      organization:, inventory:, goods_receipt_item: receipt_item,
      code: 'CROSS-BRANCH-LOT', quantity: 0
    )

    expect(lot).not_to be_valid
    expect(lot.errors[:goods_receipt_item]).to be_present
  end

  it 'rejects a receipt item for a different product' do
    other_product = create(:product, organization:)
    inventory = create(:inventory, organization:, branch:, product: other_product)

    lot = described_class.new(
      organization:, inventory:, goods_receipt_item: receipt_item,
      code: 'CROSS-PRODUCT-LOT', quantity: 0
    )

    expect(lot).not_to be_valid
    expect(lot.errors[:goods_receipt_item]).to be_present
  end
end
