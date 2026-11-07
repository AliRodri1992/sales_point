# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial product pricing' do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, price: 100, cost: 25) }
  let(:currency) { Currency.find_by(code: 'MXN') || create(:currency, code: 'MXN') }

  before { currency }

  def promotion(code: 'OFFER', discount: 10, kind: 'percentage', **attributes)
    Promotion.create!(organization:, name: code, code:, currency: 'MXN', status: 'active',
                      promotion_benefits_attributes: [{ kind:, value: discount }], **attributes)
  end

  def quote(**options)
    Products::Quote.new(product:, **options).call
  end

  it 'uses decimal arithmetic and applies only the greatest discount' do
    percentage = promotion(discount: 20)
    fixed = promotion(code: 'FIXED', kind: 'fixed_amount', discount: 25)
    expect(quote.total).to eq(BigDecimal('75'))
    expect(quote.promotion).to eq(fixed)
    expect(quote(quantity: 2).total).to eq(BigDecimal('160'))
    expect(quote(quantity: 2).promotion).to eq(percentage)
    expect(PromotionRedemption.count).to eq(0)
  end

  it 'caps fixed discounts at the line subtotal and handles zero prices without division by zero' do
    promotion(kind: 'fixed_amount', discount: 1000)
    expect(quote.total).to eq(0)
    product.update!(price: 0)
    expect(product.gross_margin).to be_nil
    expect(quote.total).to eq(0)
  end

  it 'converts presentations and uses their explicit list price for the complete package' do
    presentation = product.product_presentations.create!(name: 'Box', units: 12)
    variant = product.product_variants.create!(name: 'Blue', sku: 'BLUE', options: { 'color' => 'Blue' })
    list = PriceList.create!(organization:, name: 'Retail', code: 'RETAIL', currency: 'MXN', status: 'active')
    list.price_list_items.create!(organization:, product:, product_presentation: presentation,
                                  product_variant: variant, price: 999)
    expect(quote(presentation:, quantity: 2).base_units).to eq(24)
    expect(quote(presentation:, quantity: 2).subtotal).to eq(2400)
    expect(quote(presentation:, variant:, price_list: list).subtotal).to eq(999)
  end

  it 'never interprets a base price as another currency when a list has no matching item' do
    create(:currency, code: 'USD')
    list = PriceList.create!(organization:, name: 'USD', code: 'USD', currency: 'USD', status: 'active')
    expect { quote(price_list: list) }.to raise_error(ArgumentError, /currency/)
  end

  it 'rejects invalid quantities, inactive options and options owned by another organization' do
    [0, -1, 'NaN', 'Infinity', 'bad', 1_000_001].each do |quantity|
      expect { quote(quantity:) }.to raise_error(ArgumentError)
    end
    other = create(:product)
    option = other.product_presentations.create!(name: 'Foreign', units: 1)
    expect { quote(presentation: option) }.to raise_error(ArgumentError)
    own = product.product_variants.create!(name: 'Inactive', status: 'inactive')
    expect { quote(variant: own) }.to raise_error(ArgumentError)
    product.update!(status: 'inactive')
    expect { quote }.to raise_error(ArgumentError)
  end

  it 'respects all condition kinds, start-inclusive and end-exclusive dates and tenant isolation' do
    offer = promotion(starts_at: Time.current, ends_at: 1.day.from_now)
    offer.promotion_conditions.create!(kind: 'product', product:)
    offer.promotion_conditions.create!(kind: 'min_quantity', quantity: 2)
    offer.promotion_conditions.create!(kind: 'min_subtotal', amount: 150)
    offer.promotion_conditions.create!(kind: 'customer_segment', customer_segment: 'wholesale')
    expect(quote(quantity: 2, customer_segment: 'wholesale').discount).to eq(20)
    expect(quote(quantity: 1, customer_segment: 'wholesale').discount).to eq(0)
    expect(quote(quantity: 2, customer_segment: 'retail').discount).to eq(0)
    expect(quote(quantity: 2, customer_segment: 'wholesale', at: offer.ends_at).discount).to eq(0)
    expect(quote(quantity: 2, customer_segment: 'wholesale', at: offer.starts_at - 1.second).discount).to eq(0)
    offer.update!(status: 'archived')
    Promotion.create!(organization: create(:organization), name: 'Foreign', code: 'FOREIGN',
                      currency: 'MXN', status: 'active',
                      promotion_benefits_attributes: [{ kind: 'percentage', value: 90 }])
    expect(quote(quantity: 2, customer_segment: 'wholesale').discount).to eq(0)
  end

  it 'registers redemption once, enforces quotas and rejects idempotency key reuse with a different quantity' do
    offer = promotion(usage_limit: 1, customer_limit: 1)
    options = { product:, quantity: 2, customer_reference: 'CUSTOMER-1', idempotency_key: 'SALE-1' }
    redemption = Products::RedeemPromotion.new(**options).call
    expect(Products::RedeemPromotion.new(**options).call).to eq(redemption)
    expect(offer.promotion_redemptions.count).to eq(1)
    expect(redemption.snapshot).to include('promotion_code' => 'OFFER', 'discount' => '20.0')
    expect { Products::RedeemPromotion.new(**options, quantity: 3).call }
      .to raise_error(Products::RedeemPromotion::IdempotencyConflict)
    expect { Products::RedeemPromotion.new(**options, idempotency_key: 'SALE-2').call }
      .to raise_error(Products::RedeemPromotion::Unavailable)
    expect(redemption.update(discount: 0)).to be(false)
    expect(redemption.destroy).to be(false)
  end

  it 'requires a customer identifier for promotions with customer limits' do
    promotion(customer_limit: 1)
    expect(quote.discount).to eq(0)
    expect(quote(customer_reference: 'CUSTOMER-1').discount).to eq(10)
  end

  it 'rejects cross-product barcodes and invalid conversions' do
    other = create(:product, organization:)
    variant = other.product_variants.create!(name: 'Other')
    barcode = product.product_barcodes.build(value: '750000000001', product_variant: variant)
    expect(barcode).not_to be_valid
    expect(barcode.errors[:product_variant]).to be_present
    expect(product.product_presentations.build(name: 'Box', units: 0)).not_to be_valid
    expect(product.product_variants.build(name: 'Invalid', options: [])).not_to be_valid
  end

  it 'keeps a canonical primary barcode when the legacy barcode changes' do
    product.update!(barcode: '750000000001')
    product.update!(barcode: '750000000002')
    expect(product.product_barcodes.where(primary: true).pluck(:value)).to eq(['750000000002'])
    product.update!(barcode: '750000000001')
    expect(product.product_barcodes.where(primary: true).pluck(:value)).to eq(['750000000001'])
    product.update!(barcode: nil)
    expect(product.product_barcodes.where(primary: true)).to be_empty
  end
end
