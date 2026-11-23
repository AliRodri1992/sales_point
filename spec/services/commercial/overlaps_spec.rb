# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Commercial::Overlaps do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:) }

  before { create(:currency, code: 'MXN') }

  it 'reports only active, same-tenant price lists with a potentially overlapping product and audience' do
    list = build_list('FOCUS', customer_segment: 'Wholesale')
    matching = build_list('MATCH', customer_segment: 'Wholesale')
    build_list('UNRELATED', customer_segment: 'Retail')
    build_list('LATER', starts_at: 3.days.from_now)
    build_list('OTHER-PRODUCT', item: create(:product, organization:))
    foreign = create(:organization)
    build_list('FOREIGN', company: foreign, item: create(:product, organization: foreign))
    list.update!(ends_at: 1.day.from_now)

    expect(described_class.new(list).call).to contain_exactly(matching)
  end

  it 'reports potentially overlapping campaign schedules without asserting eligibility' do
    offer = build_promotion('FOCUS', ends_at: 1.day.from_now)
    matching = build_promotion('MATCH')
    build_promotion('LATER', starts_at: 3.days.from_now)

    expect(described_class.new(offer).call).to contain_exactly(matching)
  end

  def build_list(code, company: organization, item: product, **attributes)
    company.price_lists.create!(name: code, code:, currency: 'MXN', status: 'active', **attributes,
                                price_list_items_attributes: [{ product_id: item.id, price: 100 }])
  end

  def build_promotion(code, **attributes)
    organization.promotions.create!(name: code, code:, currency: 'MXN', status: 'active', **attributes,
                                    promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
  end
end
