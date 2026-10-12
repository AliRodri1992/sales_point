# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::CostComparison do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:) }

  it 'orders alternatives by normalized landed cost within one currency' do
    supplier_a = create(:supplier, organization:)
    supplier_b = create(:supplier, organization:)
    SupplierProduct.create!(
      organization:, product:, supplier: supplier_a, currency: supplier_a.currency,
      purchase_price: 240, presentation_name: 'Box', units_per_package: 24
    )
    SupplierProduct.create!(
      organization:, product:, supplier: supplier_b, currency: supplier_a.currency,
      purchase_price: 220, presentation_name: 'Box', units_per_package: 20
    )

    entries = described_class.call(organization:, product:)
    expect(entries.pluck(:cost_per_unit)).to eq([10, 11])
    expect(entries.pluck(:offer).map(&:supplier)).to eq([supplier_a, supplier_b])
  end

  it 'does not compare another organization product' do
    foreign_product = create(:product, organization: create(:organization))
    expect(described_class.call(organization:, product: foreign_product)).to be_empty
  end
end
