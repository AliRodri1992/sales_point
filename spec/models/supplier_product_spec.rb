# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierProduct, type: :model do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:currency) { supplier.currency }

  def offer_attributes
    {
      organization:, supplier:, product:, currency:,
      presentation_name: 'Box', units_per_package: 24,
      purchase_price: 240, discount_percent: 5, freight_amount: 12,
      nonrecoverable_tax: 0
    }
  end

  it 'normalizes discounted landed cost by the package conversion factor' do
    offer = described_class.create!(offer_attributes)
    expect(offer.unit_cost).to eq(BigDecimal('10'))
  end

  it 'records immutable price snapshots on creation and subsequent changes' do
    offer = described_class.create!(offer_attributes)
    expect(offer.price_history.count).to eq(1)
    offer.update!(purchase_price: 300)
    expect(offer.price_history.order(:id).pluck(:purchase_price)).to eq([240, 300])
  end

  it 'rejects another organization product' do
    offer = described_class.new(offer_attributes.merge(product: create(:product, organization: create(:organization))))
    expect(offer).not_to be_valid
    expect(offer.errors[:product]).to be_present
  end

  it 'rejects another organization supplier' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    offer = described_class.new(offer_attributes.merge(supplier: foreign_supplier))
    expect(offer).not_to be_valid
    expect(offer.errors[:supplier]).to be_present
  end

  it 'supports multiple purchasing presentations from the same supplier' do
    described_class.create!(offer_attributes)
    second = described_class.new(offer_attributes.merge(presentation_name: 'Pack of 6',
                                                        units_per_package: 6, purchase_price: 75))

    expect(second).to be_valid
    expect { second.save! }.to change(described_class, :count).by(1)
  end

  it 'preserves historical presentation names when an offer changes' do
    offer = described_class.create!(offer_attributes)
    offer.update!(presentation_name: 'Pack of 24')

    expect(offer.price_history.order(:id).pluck(:presentation_name)).to eq(['Box', 'Pack of 24'])
  end

  it 'allows a single preferred provider per organization and product' do
    described_class.create!(offer_attributes.merge(preferred: true))
    second_supplier = create(:supplier, organization:)
    other = described_class.new(offer_attributes.merge(supplier: second_supplier, preferred: true))
    expect(other).not_to be_valid
  end
end
