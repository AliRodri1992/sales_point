# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Purchases::Costing do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:product) { create(:product, organization:) }
  let(:order) do
    PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency, requested_by: user,
      freight_amount: 12, insurance_amount: 3, exchange_rate: 1
    )
  end

  it 'allocates freight and insurance to landed unit cost' do
    item = order.purchase_order_items.create!(
      product:, quantity: 10, units_per_package: 10, unit_price: 100, discount_percent: 5
    )
    order.update!(status: :ordered)
    receipt = Purchases::Receive.call(
      order:, user:, idempotency_key: 'costing-1',
      entries: [{ purchase_order_item_id: item.id, delivered_quantity: 10,
                  accepted_quantity: 10, damaged_quantity: 0 }]
    )
    entry = receipt.goods_receipt_items.first

    expect(entry.landed_unit_cost).to eq(BigDecimal('11'))
    expect(entry.purchase_cost_allocation).to have_attributes(
      goods_amount: 95, freight_amount: 12, insurance_amount: 3
    )
  end

  it 'allocates actual freight, additional expenses and discounts per accepted receipt' do
    item = order.purchase_order_items.create!(
      product:, quantity: 10, units_per_package: 10, unit_price: 100, discount_percent: 5
    )
    order.update!(status: :ordered)
    receipt = Purchases::Receive.call(
      order:, user:, idempotency_key: 'cost-actual',
      actual_costs: {
        actual_freight_amount: 20, actual_insurance_amount: 0,
        extra_expenses_amount: 10, additional_discount_amount: 5
      },
      entries: [{ purchase_order_item_id: item.id, delivered_quantity: 5,
                  accepted_quantity: 5, damaged_quantity: 0 }]
    )
    allocation = receipt.goods_receipt_items.first.purchase_cost_allocation
    expect(allocation).to have_attributes(freight_amount: 20, insurance_amount: 0,
                                          extra_expenses_amount: 10, additional_discount_amount: 5)
    expect(allocation.landed_unit_cost).to eq(BigDecimal('14.5'))
  end

  it 'returns zero cost when no merchandise is accepted' do
    cost = described_class.landed_cost(
      entry: GoodsReceiptItem.new(accepted_quantity: 0),
      goods: 0, freight: 10, insurance: 0, exchange_rate: 1
    )
    expect(cost).to eq(0)
  end
end
