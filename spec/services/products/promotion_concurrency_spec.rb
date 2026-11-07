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
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    workers = products.map.with_index do |product, index|
      Thread.new do
        ApplicationRecord.connection_pool.with_connection do
          ready << true
          start.pop
          results << Products::RedeemPromotion.new(product:, idempotency_key: "SALE-#{index}").call
        rescue StandardError => e
          results << e
        end
      end
    end
    products.size.times { ready.pop }
    workers.each { start << true }
    workers.each(&:join)
    outcomes = workers.map { results.pop }
    expect(outcomes.count { |value| value.is_a?(PromotionRedemption) }).to eq(1)
    expect(outcomes.count { |value| value.is_a?(Products::RedeemPromotion::Unavailable) }).to eq(1)
    expect(offer.promotion_redemptions.count).to eq(1)
  end
end
