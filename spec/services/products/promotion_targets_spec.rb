# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Promotion target eligibility' do
  let(:organization) { create(:organization) }
  let(:category) { create(:category, organization:) }
  let(:first_product) { create(:product, organization:, category:, price: 100) }
  let(:second_product) { create(:product, organization:, category:, price: 100) }
  let(:offer) do
    Promotion.create!(organization:, name: 'Targeted offer', code: 'TARGET', currency: 'MXN', status: 'active',
                      promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
  end

  before { create(:currency, code: 'MXN') }

  it 'applies to either included product but never to an unlisted product' do
    [first_product, second_product].each do |product|
      offer.promotion_conditions.create!(kind: 'product', product:)
    end
    offer.promotion_conditions.create!(kind: 'min_quantity', quantity: 2)

    expect(Products::Quote.new(product: first_product, quantity: 2).call.discount).to eq(20)
    expect(Products::Quote.new(product: second_product, quantity: 2).call.discount).to eq(20)
    expect(Products::Quote.new(product: first_product).call.discount).to eq(0)
    unlisted = create(:product, organization:, category:, price: 100)
    expect(Products::Quote.new(product: unlisted, quantity: 2).call.discount).to eq(0)
  end

  it 'applies to either category while retaining other conditions' do
    another_category = create(:category, organization:)
    second_product.update!(category: another_category)
    [category, another_category].each do |target|
      offer.promotion_conditions.create!(kind: 'category', category: target)
    end
    offer.promotion_conditions.create!(kind: 'min_subtotal', amount: 150)

    expect(Products::Quote.new(product: first_product, quantity: 2).call.discount).to eq(20)
    expect(Products::Quote.new(product: second_product, quantity: 2).call.discount).to eq(20)
    expect(Products::Quote.new(product: first_product).call.discount).to eq(0)
  end

  it 'rejects new associations with inactive, retired or foreign categories' do
    inactive = create(:category, organization:, status: 'inactive')
    retired = create(:category, organization:, deleted_at: Time.current)
    foreign = create(:category, organization: create(:organization))

    [inactive, retired, foreign].each do |target|
      condition = offer.promotion_conditions.build(kind: 'category', category: target)
      expect(condition).not_to be_valid
      expect(condition.errors[:category]).to be_present
    end
  end

  it 'rejects a new association with an inactive product' do
    inactive = create(:product, organization:, status: 'inactive')
    condition = offer.promotion_conditions.build(kind: 'product', product: inactive)

    expect(condition).not_to be_valid
    expect(condition.errors[:product]).to be_present
  end
end
