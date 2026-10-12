# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventory, type: :model do
  it 'keeps stock independently by branch' do
    organization = create(:organization)
    product = create(:product, organization:)
    first = create(:inventory, organization:, product:, branch: create(:branch, organization:), stock: 12)
    second = create(:inventory, organization:, product:, branch: create(:branch, organization:, name: 'Sucursal Norte'), stock: 3)

    expect(first.stock).to eq(12)
    expect(second.stock).to eq(3)
  end

  it 'rejects products belonging to another organization' do
    inventory = build(:inventory, product: create(:product, organization: create(:organization)))
    expect(inventory).not_to be_valid
  end

  it 'rejects invalid maximum and minimum levels' do
    inventory = build(:inventory, min_stock: 20, max_stock: 10)
    expect(inventory).not_to be_valid
  end
end
