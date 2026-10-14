# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase return service decision paths' do
  let(:actor) { build_stubbed(:user) }
  let(:service) { Purchases::ProcessReturn }
  let(:receipt_lots) { double('receipt lots') }
  let(:receipt_item) { double('receipt item', inventory_lots: receipt_lots) }
  let(:entry) do
    double(
      'return entry', quantity: 3.to_d, goods_receipt_item: receipt_item,
      purchase_return_id: 7, stock_quarantined?: false
    )
  end
  let(:lot_inventory) { double('inventory') }
  let(:lot) { double('lot', inventory: lot_inventory, quantity: 5.to_d) }

  def available_lots(*lots)
    allow(receipt_lots).to receive(:available).and_return(receipt_lots)
    allow(receipt_lots).to receive(:where).and_return(receipt_lots)
    allow(receipt_lots).to receive(:order).and_return(lots)
  end

  def quarantined_lots(*lots)
    allow(receipt_lots).to receive(:quarantined).and_return(receipt_lots)
    allow(receipt_lots).to receive(:where).and_return(receipt_lots)
    allow(receipt_lots).to receive(:order).and_return(lots)
  end

  it 'rejects accepted merchandise returns without available lots' do
    available_lots
    expect { service.return_accepted!(entry, user: actor) }
      .to raise_error(ArgumentError, /Not enough stock/)
  end

  it 'consumes accepted inventory from the available receipt lot' do
    available_lots(lot)
    allow(Inventories::FefoAllocator).to receive(:consume_lot!)
    expect { service.return_accepted!(entry, user: actor) }.not_to raise_error
    expect(Inventories::FefoAllocator).to have_received(:consume_lot!).with(
      hash_including(inventory: lot_inventory, lot:, quantity: 3.to_d, kind: 'return')
    )
  end

  it 'rejects accepted returns when lots do not contain enough items' do
    few = double('lot', inventory: lot_inventory, quantity: 1.to_d)
    available_lots(few)
    allow(Inventories::FefoAllocator).to receive(:consume_lot!)
    expect { service.return_accepted!(entry, user: actor) }
      .to raise_error(ArgumentError, /Not enough stock/)
  end

  it 'skips subsequent lots after returning the full requested amount' do
    next_lot = double('second lot')
    available_lots(lot, next_lot)
    allow(Inventories::FefoAllocator).to receive(:consume_lot!)
    service.return_accepted!(entry, user: actor)
    expect(Inventories::FefoAllocator).to have_received(:consume_lot!).once
  end

  it 'rejects missing quarantined merchandise stock' do
    quarantined_lots
    expect { service.return_quarantined!(entry) }
      .to raise_error(ArgumentError, /Not enough quarantined/)
  end

  it 'returns quarantined merchandise through its locked receipt lot' do
    quarantined_lots(lot)
    allow(lot).to receive(:with_lock).and_yield
    allow(lot).to receive(:update!)
    allow(service).to receive(:return_quarantined_serials!)
    expect { service.return_quarantined!(entry) }.not_to raise_error
    expect(lot).to have_received(:update!).with(quantity: 2.to_d, status: :quarantined)
  end

  it 'depletes a quarantined receipt lot when all its units are returned' do
    exact = double('lot', quantity: 3.to_d)
    quarantined_lots(exact)
    allow(exact).to receive(:with_lock).and_yield
    allow(exact).to receive(:update!)
    allow(service).to receive(:return_quarantined_serials!)
    service.return_quarantined!(entry)
    expect(exact).to have_received(:update!).with(quantity: 0.to_d, status: :depleted)
  end

  it 'does not return individual serials for nonserialized stock' do
    product = double('product', tracking_serial?: false)
    serial_lot = double('lot', inventory: double(product:))
    expect { service.return_quarantined_serials!(serial_lot, 1.to_d) }.not_to raise_error
  end

  it 'rejects fractional serialized quantities' do
    product = double('product', tracking_serial?: true)
    serial_lot = double('lot', inventory: double(product:))
    expect { service.return_quarantined_serials!(serial_lot, 1.5.to_d) }
      .to raise_error(ArgumentError, /whole numbers/)
  end

  it 'rejects insufficient quarantined serial numbers' do
    product = double('product', tracking_serial?: true)
    serials = double('serials')
    allow(serials).to receive(:quarantined).and_return(serials)
    allow(serials).to receive(:order).and_return(serials)
    allow(serials).to receive(:limit).and_return([])
    serial_lot = double('lot', inventory: double(product:), inventory_serials: serials)
    expect { service.return_quarantined_serials!(serial_lot, 2.to_d) }
      .to raise_error(ArgumentError, /Insufficient quarantined serial/)
  end

  it 'marks matching serials returned' do
    product = double('product', tracking_serial?: true)
    serials = double('serials')
    serial = double('serial')
    allow(serials).to receive(:quarantined).and_return(serials)
    allow(serials).to receive(:order).and_return(serials)
    allow(serials).to receive(:limit).and_return([serial])
    allow(serial).to receive(:update!)
    serial_lot = double('lot', inventory: double(product:), inventory_serials: serials)
    service.return_quarantined_serials!(serial_lot, 1.to_d)
    expect(serial).to have_received(:update!).with(status: :returned)
  end
end
