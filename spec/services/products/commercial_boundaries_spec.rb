# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial validation boundaries' do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, price: 100) }
  let(:currency) { create(:currency, code: 'MXN') }

  before { currency }

  describe 'scanner codes' do
    { 'ean13' => '4006381333931', 'ean8' => '96385074', 'upca' => '036000291452',
      'code128' => 'COFFEE-001', 'qr' => 'https://example.com/item/1' }.each do |format, code|
      it "accepts a usable #{format} identifier" do
        expect(Products::BarcodeFormat.valid?(code, format)).to be(true)
      end
    end

    %w[4006381333932 123 ABC].each do |code|
      it "rejects invalid EAN identifiers: #{code}" do
        expect(Products::BarcodeFormat.valid?(code, 'ean13')).to be(false)
      end
    end

    it 'rejects unknown barcode types and invalid model values' do
      expect(Products::BarcodeFormat.valid?('123', 'unknown')).to be(false)
      expect(Products::BarcodeFormat.valid?("bad\ncode", 'code128')).to be(false)
      expect(Products::BarcodeFormat.valid?('', 'qr')).to be(false)
      expect(product.product_barcodes.build(value: '123', symbology: 'ean13')).not_to be_valid
    end
  end

  describe 'price periods' do
    let(:list) { PriceList.create!(organization:, name: 'Retail', code: 'RETAIL', currency: 'MXN', status: 'active') }

    it 'rejects reversed and invalid dates instead of silently activating an unlimited period' do
      list.starts_at = Time.current
      list.ends_at = 1.day.ago
      expect(list).not_to be_valid
      list.starts_at = 'not-a-date'
      list.ends_at = nil
      expect(list).not_to be_valid
      expect(list.errors[:starts_at]).to be_present
    end

    it 'permits adjacent prices and rejects overlapping prices in memory and at the database boundary' do
      boundary = 1.day.from_now.change(usec: 0)
      first = list.price_list_items.create!(organization:, product:, price: 100, ends_at: boundary)
      second = list.price_list_items.create!(organization:, product:, price: 90, starts_at: boundary)
      expect(Products::Quote.new(product:, price_list: list, at: boundary).call.unit_price).to eq(90)
      second.starts_at = boundary - 1.second
      expect(second).not_to be_valid
      expect do
        PriceListItem.transaction(requires_new: true) do
          PriceListItem.connection.execute('SET CONSTRAINTS commercial_price_periods IMMEDIATE')
          second.save!(validate: false)
        end
      end.to raise_error(ActiveRecord::StatementInvalid)
      expect(first.reload.price).to eq(100)
    end

    it 'rejects duplicated submitted prices before either row is stored' do
      list.price_list_items.build(organization:, product:, price: 100)
      list.price_list_items.build(organization:, product:, price: 90)
      expect(list).not_to be_valid
      expect(list.errors[:base]).to be_present
    end

    it 'rejects foreign, archived, out of period and wrong-segment lists' do
      list.update!(customer_segment: 'wholesale')
      expect { Products::Quote.new(product:, price_list: list).call }.to raise_error(ArgumentError)
      expect(Products::Quote.new(product:, price_list: list, customer_segment: 'wholesale').call.unit_price).to eq(100)
      list.update!(status: 'archived')
      expect { Products::Quote.new(product:, price_list: list, customer_segment: 'wholesale').call }
        .to raise_error(ArgumentError)
      list.update!(status: 'active', starts_at: 1.day.from_now)
      expect { Products::Quote.new(product:, price_list: list, customer_segment: 'wholesale').call }
        .to raise_error(ArgumentError)
      foreign = PriceList.create!(organization: create(:organization), name: 'Foreign', code: 'FOREIGN',
                                  currency: 'MXN', status: 'active')
      expect { Products::Quote.new(product:, price_list: foreign).call }.to raise_error(ArgumentError)
    end
  end

  describe 'promotion conditions' do
    let(:offer) { Promotion.create!(organization:, name: 'Offer', code: 'OFFER', currency: 'MXN', status: 'draft') }

    it 'requires a benefit before activation and prevents removal of every active benefit' do
      offer.status = 'active'
      expect(offer).not_to be_valid
      benefit = offer.promotion_benefits.build(kind: 'percentage', value: 10)
      expect(offer).to be_valid
      benefit.mark_for_destruction
      expect(offer).not_to be_valid
    end

    it 'enforces percentage, minimum values, required condition inputs and tenant ownership' do
      expect(offer.promotion_benefits.build(kind: 'percentage', value: 101)).not_to be_valid
      expect(offer.promotion_benefits.build(kind: 'fixed_amount', value: -1)).not_to be_valid
      %w[product category min_quantity min_subtotal customer_segment].each do |kind|
        expect(offer.promotion_conditions.build(kind:)).not_to be_valid
      end
      foreign = create(:product)
      expect(offer.promotion_conditions.build(kind: 'product', product: foreign)).not_to be_valid
    end

    it 'matches categories and minimum amounts, rejecting missing segments and unknown conditions' do
      category = create(:category)
      product.update!(category:)
      offer.promotion_conditions.build(kind: 'category', category:)
      offer.promotion_conditions.build(kind: 'min_subtotal', amount: 150)
      context = { product:, quantity: 2, subtotal: 200 }
      expect(Products::PromotionEligibility.new(offer, **context).eligible?).to be(true)
      expect(Products::PromotionEligibility.new(offer, **context, subtotal: 100).eligible?).to be(false)
      offer.promotion_conditions.build(kind: 'customer_segment', customer_segment: 'wholesale')
      expect(Products::PromotionEligibility.new(offer, **context).eligible?).to be(false)
      expect(Products::PromotionEligibility.new(offer, **context, segment: 'wholesale').eligible?).to be(true)
      offer.promotion_conditions.build(kind: 'unknown')
      expect(Products::PromotionEligibility.new(offer, **context, segment: 'wholesale').eligible?).to be(false)
    end

    it 'enforces a customer limit independently from the total limit' do
      offer.promotion_benefits.create!(kind: 'percentage', value: 10)
      offer.update!(status: 'active', customer_limit: 1, usage_limit: 5)
      Products::RedeemPromotion.new(product:, customer_reference: 'ONE', idempotency_key: 'ONE-1').call
      expect(Products::Quote.new(product:, customer_reference: 'ONE').call.discount).to eq(0)
      expect(Products::Quote.new(product:, customer_reference: 'TWO').call.discount).to eq(10)
      expect { Products::RedeemPromotion.new(product:, customer_reference: 'TWO', idempotency_key: 'ONE-1').call }
        .to raise_error(Products::RedeemPromotion::IdempotencyConflict)
    end
  end

  it 'preserves commercial currencies and permits archiving after a currency becomes inactive' do
    dollar = create(:currency, code: 'USD')
    [PriceList, Promotion].each do |model|
      record = model.create!(organization:, name: 'Currency history', code: 'CURRENCY', currency: 'MXN')
      record.currency = dollar.code
      expect(record).not_to be_valid
      expect(record.errors[:currency]).to include(I18n.t('admin.catalog_design.currency_fixed'))
      record.reload
      currency.update!(active: false)
      expect(record.update(status: 'archived')).to be(true)
      expect(record.reload.currency).to eq('MXN')
      currency.update!(active: true)
    end
    currency.update!(active: false)
    unavailable = PriceList.new(organization:, name: 'Unavailable currency', code: 'INACTIVE', currency: 'MXN')
    expect(unavailable).not_to be_valid
  end
end
