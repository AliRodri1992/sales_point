# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase landed cost allocation decision paths' do
  def order(total:, quantity:)
    lines = double
    allow(lines).to receive(:sum).with(:quantity).and_return(quantity)
    double(goods_total: total, purchase_order_items: lines)
  end

  def entry(accepted: 2, total: 10, quantity: 10)
    line = double(line_total: total, quantity:)
    double(accepted_quantity: accepted.to_d, purchase_order_item: line)
  end

  def receipt_entry(items)
    records = double
    allow(records).to receive(:includes).with(:purchase_order_item).and_return(items)
    receipt = double(goods_receipt_items: records)
    double(goods_receipt: receipt, accepted_quantity: items.sum(&:accepted_quantity))
  end

  it 'weights an order by goods value when known' do
    result = Purchases::Costing.weight_in_order(order(total: 100, quantity: 10), entry, 25.to_d)
    expect(result).to eq(0.25)
  end

  it 'weights an order by accepted items when its value is zero' do
    result = Purchases::Costing.weight_in_order(order(total: 0, quantity: 10), entry, 0.to_d)
    expect(result).to eq(0.2)
  end

  it 'returns zero weight for an empty purchase order' do
    result = Purchases::Costing.weight_in_order(order(total: 0, quantity: 0), entry, 0.to_d)
    expect(result).to eq(0)
  end

  it 'weights a receipt by its goods cost when measurable' do
    item = entry(accepted: 2, total: 10, quantity: 10)
    result = Purchases::Costing.weight_in_receipt(receipt_entry([item]), 2.to_d)
    expect(result).to eq(1)
  end

  it 'weights a zero-value receipt by accepted item counts' do
    item = entry(accepted: 2, total: 0, quantity: 10)
    result = Purchases::Costing.weight_in_receipt(receipt_entry([item]), 0.to_d)
    expect(result).to eq(1)
  end

  it 'returns zero weight for receipt without any accepted item' do
    item = entry(accepted: 0, total: 0, quantity: 10)
    result = Purchases::Costing.weight_in_receipt(receipt_entry([item]), 0.to_d)
    expect(result).to eq(0)
  end

  it 'distributes nil actual freight via quoted amounts and actual extras via receipt weight' do
    expenses = {
      actual_freight_amount: nil, actual_insurance_amount: nil,
      extra_expenses_amount: 10.to_d, additional_discount_amount: 2.to_d
    }
    receipt = double(**expenses)
    purchase = double(freight_amount: 20.to_d, insurance_amount: 10.to_d)
    values = Purchases::Costing.expenses(receipt, purchase, 0.5.to_d, 0.25.to_d)
    expect(values).to include(freight: 5, insurance: 2.5, extra_expenses: 5, additional_discount: 1)
  end

  it 'allocates actual carrier and insurance expenses when supplied' do
    expenses = {
      actual_freight_amount: 16.to_d, actual_insurance_amount: 8.to_d,
      extra_expenses_amount: 0.to_d, additional_discount_amount: 0.to_d
    }
    receipt = double(**expenses)
    purchase = double(freight_amount: 20.to_d, insurance_amount: 10.to_d)
    result = Purchases::Costing.expenses(receipt, purchase, 0.5.to_d, 0.25.to_d)
    expect(result).to include(freight: 8, insurance: 4)
  end

  it 'defaults optional expenses to zero in landed cost' do
    record = entry(accepted: 2)
    data = { entry: record, goods: 20, exchange_rate: 1, freight: 2, insurance: 0 }
    result = Purchases::Costing.landed_cost(**data)
    expect(result).to eq(11)
  end
end
