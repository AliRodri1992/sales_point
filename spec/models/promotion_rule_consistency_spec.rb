# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Promotion, type: :model do
  let(:organization) { create(:organization) }
  let(:promotion) { organization.promotions.build(name: 'Rule validation', currency: 'MXN') }

  before { create(:currency, code: 'MXN') }

  it 'keeps a draft valid when the untouched default percentage placeholder is submitted' do
    promotion.assign_attributes(promotion_benefits_attributes: {
      '0' => { kind: 'percentage', value: '' }
    })
    expect(promotion).to be_valid
    expect(promotion.promotion_benefits).to be_empty
  end

  it 'does not discard a non-default benefit without its value' do
    promotion.assign_attributes(promotion_benefits_attributes: {
      '0' => { kind: 'fixed_amount', value: '' }
    })
    expect(promotion).not_to be_valid
    expect(promotion.promotion_benefits.first.errors[:value]).to be_present
  end

  it 'rejects duplicate products without relying on the browser' do
    product = create(:product, organization:)
    2.times { promotion.promotion_conditions.build(kind: 'product', product:) }
    expect(promotion).not_to be_valid
    expect(promotion.errors.details[:promotion_conditions].map { |error| error[:error] }).to include(:duplicate_target)
  end

  it 'rejects an included and excluded product even when both rows are valid individually' do
    product = create(:product, organization:)
    promotion.promotion_conditions.build(kind: 'product', product:)
    promotion.promotion_conditions.build(kind: 'excluded_product', product:)
    expect(promotion).not_to be_valid
    expect(promotion.errors.details[:promotion_conditions].map { |error| error[:error] }).to include(:contradictory_target)
  end

  it 'accepts different included products but rejects multiple minimum quantity rules' do
    products = Array.new(2) { create(:product, organization:) }
    products.each { |product| promotion.promotion_conditions.build(kind: 'product', product:) }
    expect(promotion).to be_valid
    promotion.promotion_conditions.build(kind: 'min_quantity', quantity: 2)
    promotion.promotion_conditions.build(kind: 'min_quantity', quantity: 3)
    expect(promotion).not_to be_valid
    expect(promotion.errors.details[:promotion_conditions].map { |error| error[:error] }).to include(:repeated_rule)
  end

  it 'allows replacing a persisted rule within the same transaction' do
    promotion.save!
    old = promotion.promotion_conditions.create!(kind: 'min_quantity', quantity: 2)
    promotion.assign_attributes(promotion_conditions_attributes: {
      '0' => { id: old.id, _destroy: '1' },
      '1' => { kind: 'min_quantity', quantity: 3 }
    })
    expect(promotion).to be_valid
    promotion.save!
    expect(promotion.reload.promotion_conditions.pluck(:quantity)).to eq([3])
  end

  it 'rejects more than twenty live conditions' do
    21.times { |index| promotion.promotion_conditions.build(kind: 'min_quantity', quantity: index + 1) }
    expect(promotion).not_to be_valid
    expect(promotion.errors.details[:promotion_conditions].map { |error| error[:error] }).to include(:too_many)
  end
end
