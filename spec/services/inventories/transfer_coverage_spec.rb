# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventories::Transfer do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:) }
  let(:origin) do
    Inventory.create!(organization:, branch: create(:branch, organization:), product:, stock: 12, min_stock: 0)
  end
  let(:destination) do
    Inventory.create!(organization:, branch: create(:branch, organization:), product:, stock: 0, min_stock: 0)
  end

  it 'transfers stock between organization branches with immutable movement records' do
    expect { described_class.call(from: origin, to: destination, quantity: 3, reference: 'TX-001') }
      .to change(InventoryMovement, :count).by(2)

    expect(origin.reload.stock).to eq(9)
    expect(destination.reload.stock).to eq(3)
    expect(origin.inventory_movements.last.kind).to eq('transfer_out')
    expect(destination.inventory_movements.last.kind).to eq('transfer_in')
  end

  it 'blocks transfers across organizations' do
    foreign = Inventory.create!(
      organization: create(:organization), product: create(:product),
      branch: create(:branch), stock: 0
    )
    expect { described_class.call(from: origin, to: foreign, quantity: 1) }
      .to raise_error(ArgumentError, /organizations/)
  end

  it 'blocks transfers between different products' do
    another = Inventory.create!(
      organization:, branch: create(:branch, organization:),
      product: create(:product, organization:), stock: 0
    )
    expect { described_class.call(from: origin, to: another, quantity: 1) }
      .to raise_error(ArgumentError, /Product mismatch/)
  end

  it 'blocks transfers to the same branch inventory' do
    expect { described_class.call(from: origin, to: origin, quantity: 1) }
      .to raise_error(ArgumentError, /differ/)
  end

  [0, -1].each do |quantity|
    it "rejects transfer quantity #{quantity}" do
      expect { described_class.call(from: origin, to: destination, quantity:) }
        .to raise_error(ArgumentError, /positive/)
    end
  end

  it 'rolls back destination changes when stock is insufficient' do
    expect do
      described_class.call(from: origin, to: destination, quantity: 13)
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(origin.reload.stock).to eq(12)
    expect(destination.reload.stock).to eq(0)
  end
end
