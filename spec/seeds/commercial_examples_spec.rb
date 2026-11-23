# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/commercial_examples')

RSpec.describe CommercialExamples, type: :model do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  before do
    create(:currency, code: 'MXN')
    category = create(:category, organization:)
    3.times do |index|
      create(:product, organization:, category:, code: format('PROD%04d', index + 1), price: 100, cost: 60)
    end
    create(:product, organization:, code: 'PROD0004', status: 'inactive')
    create(:product, organization: other_organization, code: 'PROD0001')
  end

  def seed_examples
    described_class.seed_price_lists!(organization:)
    described_class.seed_promotions!(organization:)
  end

  it 'loads twelve lists and campaigns with useful, valid tenant-scoped commercial rules' do
    seed_examples

    expect(organization.price_lists.count).to eq(12)
    expect(organization.promotions.count).to eq(12)
    expect(organization.price_lists.map(&:effective_status))
      .to include(*%w[draft active scheduled paused expired archived])
    expect(organization.promotions.map(&:effective_status))
      .to include(*%w[draft active scheduled paused expired archived])
    rows = PriceListItem.where(organization:)
    expect(rows.count).to eq(36)
    expect(rows.distinct.pluck(:minimum_quantity)).to match_array([0, 5, 10])
    expect(rows.all? { |row| row.product.active? && row.product.organization_id == organization.id }).to be(true)
    expect(rows.all? { |row| row.price >= row.product.cost }).to be(true)
    conditions = PromotionCondition.where(organization:)
    expect(conditions.distinct.pluck(:kind))
      .to include(*%w[product category min_quantity min_subtotal customer_segment])
    expect(conditions.where.not(product_id: nil).all? { |rule| rule.product.active? }).to be(true)
    expect(PromotionBenefit.where(organization:).distinct.pluck(:kind)).to match_array(%w[percentage fixed_amount])
    expect(PromotionRedemption.where(organization:)).not_to exist
    expect(other_organization.price_lists).to be_empty
    expect(other_organization.promotions).to be_empty
  end

  it 'keeps manual changes and retired examples without recreating them or their children' do
    seed_examples
    list = organization.price_lists.find_by!(code: 'LP-DEMO-0001')
    campaign = organization.promotions.find_by!(code: 'PRO-DEMO-0001')
    row = list.price_list_items.first!
    row.update!(price: 98)
    list.update!(name: 'Customized list')
    campaign.update!(name: 'Customized campaign', deleted_at: Time.current)

    expect { seed_examples }.not_to(change { [PriceListItem.count, PromotionCondition.count, PromotionBenefit.count] })
    expect(list.reload.name).to eq('Customized list')
    expect(row.reload.price).to eq(98)
    expect(Promotion.with_deleted.find(campaign.id))
      .to have_attributes(name: 'Customized campaign', deleted_at: be_present)
    expect(organization.promotions.with_deleted.count).to eq(12)
    expect(organization.price_lists.count).to eq(12)
  end
end
