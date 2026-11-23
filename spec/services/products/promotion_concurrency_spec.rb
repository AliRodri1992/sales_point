# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Promotion redemption concurrency', :concurrent_db do
  it 'does not exceed one shared promotion use when two products are committed concurrently' do
    organization = create(:organization)
    create(:currency, code: 'MXN')
    products = [create(:product, organization:), create(:product, organization:)]
    offer = Promotion.create!(organization:, name: 'One use', code: 'ONE', currency: 'MXN',
                              status: 'active', usage_limit: 1,
                              promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
    outcomes = concurrent_calls(products) { |product, index| redeem(product, "SALE-#{index}") }
    expect(outcomes.count { |value| value.is_a?(PromotionRedemption) }).to eq(1)
    expect(outcomes.count { |value| value.is_a?(Products::RedeemPromotion::Unavailable) }).to eq(1)
    expect(offer.promotion_redemptions.count).to eq(1)
  end

  it 'classifies racing uses of the same idempotency key on distinct products as a conflict' do
    organization = create(:organization)
    create(:currency, code: 'MXN')
    products = Array.new(2) { create(:product, organization:) }
    offer = organization.promotions.create!(name: 'One use', currency: 'MXN', status: 'active', usage_limit: 1,
                                            promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
    outcomes = concurrent_calls(products) { |product, _| redeem(product, 'SHARED') }
    expect(outcomes.count { |value| value.is_a?(Products::RedeemPromotion::IdempotencyConflict) }).to eq(1)
    expect(outcomes.count { |value| value.is_a?(PromotionRedemption) }).to eq(1)
    expect(offer.promotion_redemptions.count).to eq(1)
  end

  def redeem(product, key)
    Products::RedeemPromotion.new(product:, idempotency_key: key).call
  rescue Products::RedeemPromotion::Unavailable, Products::RedeemPromotion::IdempotencyConflict => e
    e
  end

  def concurrent_calls(products)
    ready = Queue.new
    start = Queue.new
    workers = products.map.with_index do |product, index|
      Thread.new do
        ApplicationRecord.connection_pool.with_connection do
          ready << true
          start.pop
          yield(product, index)
        end
      end
    end
    products.size.times { ready.pop }
    workers.each { start << true }
    workers.map(&:value)
  end
end
