# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FEFO inventory selection and serialized stock branches' do
  def inventory(stock: 5)
    double(stock:, with_lock: nil)
  end

  def lot_collection(lots)
    relation = double
    allow(relation).to receive(:saleable).and_return(relation)
    allow(relation).to receive(:lock).and_return(lots)
    relation
  end

  def allocator(quantity: 2, stock: 5, lots: [])
    inv = double(stock:, inventory_lots: lot_collection(lots))
    allow(inv).to receive(:with_lock).and_yield
    Inventories::FefoAllocator.new(
      inventory: inv, quantity:, user: nil, kind: 'sale', options: {}
    )
  end

  it 'refuses invalid quantities without attempting lot selection' do
    expect { allocator(quantity: 0).call }.to raise_error(ArgumentError, /positive/)
  end

  it 'refuses a request greater than inventory balance' do
    expect { allocator(quantity: 7, stock: 5).call }.to raise_error(ArgumentError, /Insufficient inventory/)
  end

  it 'refuses stock when saleable lots are missing' do
    expect { allocator(quantity: 2).call }.to raise_error(ArgumentError, /No unexpired stock/)
  end

  it 'accepts a fulfilled lot request' do
    lot = double(quantity: 5.to_d)
    instance = allocator(quantity: 2, lots: [lot])
    allow(Inventories::FefoAllocator).to receive(:consume_lot!)
    expect { instance.call }.not_to raise_error
    expect(Inventories::FefoAllocator).to have_received(:consume_lot!).once
  end

  it 'skips extra lots when requested units have already been allocated' do
    first = double(quantity: 5.to_d)
    second = double(quantity: 10.to_d)
    instance = allocator(quantity: 2, lots: [first, second])
    allow(Inventories::FefoAllocator).to receive(:consume_lot!)
    expect(instance.allocate_lots).to eq(0)
    expect(Inventories::FefoAllocator).to have_received(:consume_lot!).once
  end

  it 'returns a remainder when the lots do not cover the requested quantity' do
    lot = double(quantity: 1.to_d)
    instance = allocator(quantity: 2, lots: [lot])
    allow(Inventories::FefoAllocator).to receive(:consume_lot!)
    expect(instance.allocate_lots).to eq(1)
  end

  def consume_serials(quantity:, kind:, serials:)
    relation = double
    allow(relation).to receive(:available).and_return(relation)
    allow(relation).to receive(:order).with(:id).and_return(relation)
    allow(relation).to receive(:limit).with(quantity.to_i).and_return(serials)
    lot = double(inventory_serials: relation)
    Inventories::FefoAllocator.consume_serials!(lot, quantity.to_d, kind)
  end

  it 'rejects missing available serial numbers' do
    expect { consume_serials(quantity: 2, kind: 'sale', serials: []) }
      .to raise_error(ArgumentError, /Not enough available serial numbers/)
  end

  it 'marks consumed serial numbers as sold' do
    serials = [double, double]
    serials.each { |serial| allow(serial).to receive(:update!).with(status: :sold) }
    consume_serials(quantity: 2, kind: 'sale', serials:)
    serials.each { |serial| expect(serial).to have_received(:update!).with(status: :sold) }
  end

  it 'marks returned serial numbers as returned' do
    serials = [double]
    allow(serials.first).to receive(:update!).with(status: :returned)
    consume_serials(quantity: 1, kind: 'return', serials:)
    expect(serials.first).to have_received(:update!).with(status: :returned)
  end
end
