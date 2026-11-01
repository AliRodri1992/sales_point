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

  it 'rejects creating a new offer for an inactive supplier' do
    supplier.update!(status: :inactive)
    offer = described_class.new(offer_attributes)

    expect(offer).not_to be_valid
    expect(offer.errors[:supplier]).to be_present
  end

  it 'prevents reactivating a historical offer when its supplier is inactive' do
    offer = described_class.create!(offer_attributes)
    offer.update!(active: false)
    supplier.update!(status: :inactive)

    expect(offer.update(active: true)).to be(false)
    expect(offer.reload.active).to be(false)
  end

  it 'does not call an unassigned offer preferred' do
    expect(described_class.new).not_to be_preferred
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

  it 'marks all presentations of the selected supplier as preferred' do
    first = described_class.create!(offer_attributes)
    second = described_class.create!(offer_attributes.merge(presentation_name: 'Pack of 6'))
    product.update!(preferred_supplier: supplier)

    expect(first.reload).to be_preferred
    expect(second.reload).to be_preferred
  end

  it 'clears preference only when the last active presentation is disabled' do
    first = described_class.create!(offer_attributes)
    second = described_class.create!(offer_attributes.merge(presentation_name: 'Pack of 6'))
    product.update!(preferred_supplier: supplier)

    first.update!(active: false)
    expect(product.reload.preferred_supplier).to eq(supplier)

    second.update!(active: false)
    expect(product.reload.preferred_supplier).to be_nil

    first.update!(active: true)
    expect(product.reload.preferred_supplier).to be_nil
  end

  it 'clears preference after removing the final available presentation' do
    offer = described_class.create!(offer_attributes)
    product.update!(preferred_supplier: supplier)

    offer.update!(deleted_at: Time.current)

    expect(product.reload.preferred_supplier).to be_nil
  end

  it 'keeps an inactive supplier offer editable without reactivation' do
    offer = described_class.create!(offer_attributes)
    supplier.update!(status: :inactive)

    expect(offer.update!(purchase_price: 310)).to be(true)
    expect(offer.reload.purchase_price).to eq(310)
  end

  it 'rejects restoring an archived offer while its supplier is inactive' do
    offer = described_class.create!(offer_attributes)
    offer.update!(deleted_at: Time.current)
    supplier.update!(status: :inactive)

    expect(offer.update(deleted_at: nil)).to be(false)
    expect(offer.errors[:supplier]).to be_present
  end

  it 'does not register another price snapshot when only notes change' do
    offer = described_class.create!(offer_attributes)
    previous = offer.price_history.count

    expect(offer.update(active: false)).to be(true)
    expect(offer.price_history.count).to eq(previous)
  end

  it 'does not clear a preferred supplier when modifying an unrelated offer' do
    offer = described_class.create!(offer_attributes)
    another_supplier = create(:supplier, organization:)
    alternative_attributes = offer_attributes.merge(supplier: another_supplier, presentation_name: 'Alternative box')
    alternative = described_class.create!(alternative_attributes)
    product.update!(preferred_supplier: supplier)

    alternative.update!(active: false)

    expect(product.reload.preferred_supplier).to eq(offer.supplier)
  end
end
