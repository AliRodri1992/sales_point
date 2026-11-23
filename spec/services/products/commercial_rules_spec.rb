# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial line pricing rules' do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, price: 100, cost: 25) }
  let(:currency) { create(:currency, code: 'MXN') }

  before { currency }

  def list(price:, **attributes)
    organization.price_lists.create!(name: 'Price list', currency: 'MXN', status: 'active',
                                     price_list_items_attributes: [{ product:, price: }], **attributes)
  end

  def offer(value:, **attributes)
    organization.promotions.create!(name: 'Promotion', currency: 'MXN', status: 'active',
                                    promotion_benefits_attributes: [{ kind: 'percentage', value: }], **attributes)
  end

  def quote(**options)
    Products::Quote.new(product:, **options).call
  end

  it 'prefers the explicit list, then the highest-priority matching segment, then the default' do
    list(price: 96, default_list: true, priority: 10)
    list(price: 94, customer_segment: 'trade', priority: 1)
    segment = list(price: 93, customer_segment: 'trade', priority: 2)
    explicit = list(price: 89)
    expect(quote.unit_price).to eq(96)
    expect(quote(customer_segment: 'trade').price_list_item.price_list).to eq(segment)
    expect(quote(customer_segment: 'trade', price_list: explicit).unit_price).to eq(89)
  end

  it 'ignores automatically assigned lists in foreign currencies or outside the current instant' do
    create(:currency, code: 'USD')
    list(price: 10, default_list: true, currency: 'USD')
    list(price: 20, default_list: true, starts_at: 1.hour.from_now)
    expect(quote).to have_attributes(unit_price: 100, currency: 'MXN')
  end

  it 'matches the greatest eligible tier in base units for the exact package' do
    catalog = list(price: 90, default_list: true)
    box = product.product_presentations.create!(name: 'Box of six', units: 6)
    catalog.price_list_items.create!(product:, product_presentation: box, price: 540)
    catalog.price_list_items.create!(product:, product_presentation: box, price: 480, minimum_quantity: 12)
    expect(quote(presentation: box, quantity: '1.99').unit_price).to eq(540)
    expect(quote(presentation: box, quantity: 2).subtotal).to eq(960)
    expect(quote(quantity: 12).unit_price).to eq(90)
  end

  it 'caps each offer before ranking, breaking equal ordinary discounts by priority and ID' do
    offer(value: 70, maximum_discount: 20, priority: 9)
    offer(value: 30)
    winner = offer(value: 30, priority: 2)
    offer(value: 30, priority: 2)
    expect(quote).to have_attributes(promotion: winner, discount: 30, total: 70)
  end

  it 'uses one eligible exclusive offer, preferring priority before the discount' do
    offer(value: 70)
    offer(value: 40, combination_mode: 'exclusive', priority: 1)
    chosen = offer(value: 10, combination_mode: 'exclusive', priority: 2)
    expect(quote).to have_attributes(promotion: chosen, discount: 10)
  end

  it 'restricts list-specific offers to the list used by the quote' do
    catalog = list(price: 90)
    special = offer(value: 50, price_list: catalog)
    expect(quote.discount).to eq(0)
    expect(quote(price_list: catalog)).to have_attributes(promotion: special, discount: 45)
  end

  it 'honors every product and category exclusion even when an inclusion matches' do
    category = create(:category, organization:)
    product.update!(category:)
    special = offer(value: 10)
    special.promotion_conditions.create!(kind: 'product', product:)
    special.promotion_conditions.create!(kind: 'excluded_product', product: create(:product, organization:))
    expect(quote.discount).to eq(10)
    excluded = special.promotion_conditions.create!(kind: 'excluded_category', category:)
    expect(quote.discount).to eq(0)
    excluded.destroy!
    special.promotion_conditions.create!(kind: 'excluded_product', product:)
    expect(quote.discount).to eq(0)
  end

  it 'preserves historical category associations but never grants a discount for a retired or foreign category' do
    category = create(:category, organization:)
    product.update!(category:)
    special = offer(value: 10)
    special.promotion_conditions.create!(kind: 'category', category:)
    expect(quote.discount).to eq(10)
    category.update!(status: 'inactive')
    expect(quote.discount).to eq(0)
    category.update!(status: 'active', deleted_at: Time.current)
    expect(quote.discount).to eq(0)
    # Recreate historical cross-tenant links that the current editor disallows.
    # rubocop:disable-next Rails/SkipsModelValidations
    category.update_columns(deleted_at: nil, organization_id: create(:organization).id)
    expect(quote.discount).to eq(0)
    # Legacy global category rows have no owning organization.
    # rubocop:disable-next Rails/SkipsModelValidations
    category.update_column(:organization_id, nil)
    expect(quote.discount).to eq(0)
    expect(special.promotion_conditions.sole.category_id).to eq(category.id)
  end

  it 'makes a campaign unavailable if an exclusion no longer names a valid product' do
    excluded = create(:product, organization:)
    special = offer(value: 10)
    special.promotion_conditions.create!(kind: 'excluded_product', product: excluded)
    expect(quote.discount).to eq(10)
    excluded.update!(status: 'inactive')
    expect(quote.discount).to eq(0)
  end

  it 'uses catalog precision for the quote, redemption and immutable automatic price selection' do
    currency.update!(decimal_places: 3)
    catalog = list(price: '9.999', default_list: true)
    offer(value: '12.5')
    options = { product:, quantity: '1.5', idempotency_key: 'LINE' }
    original = Products::RedeemPromotion.new(**options).call
    expect(original.reload.discount).to eq(BigDecimal('1.875'))
    expect(original.snapshot).to include('subtotal' => '14.999', 'total' => '13.124',
                                         'resolved_price_list_id' => catalog.id,
                                         'price_list_item_id' => catalog.price_list_items.sole.id)
    catalog.update!(default_list: false)
    expect(Products::RedeemPromotion.new(**options).call).to eq(original)
  end

  it 'rounds amounts only at the currency precision for zero-decimal currencies' do
    currency.update!(decimal_places: 0)
    offer(value: '2.5')
    expect(quote).to have_attributes(subtotal: 100, discount: 3, total: 97)
    redemption = Products::RedeemPromotion.new(product:, idempotency_key: 'WHOLE-UNITS').call
    expect(redemption.reload.discount).to eq(3)
    expect(redemption.snapshot.fetch('total').to_d).to eq(97)
  end

  it 'previews a selected draft offer and draft list without making either eligible for a sale' do
    catalog = list(price: 80, status: 'draft')
    special = offer(value: 25, status: 'draft')
    offer(value: 80)
    simulation = Products::Quote.new(product:, price_list: catalog, promotion: special)
    expect { simulation.preview }.not_to change(PromotionRedemption, :count)
    expect(simulation.preview).to have_attributes(promotion: special, total: 60)
    expect { simulation.call }.to raise_error(ArgumentError)
    expect(quote.total).to eq(20)
  end

  it 'rejects foreign simulation targets and checks actual rule eligibility during a preview' do
    foreign = create(:organization)
    special = foreign.promotions.create!(name: 'Foreign', status: 'draft', currency: 'MXN')
    expect { Products::Quote.new(product:, promotion: special).preview }.to raise_error(ArgumentError)
    owned = offer(value: 50, status: 'draft')
    owned.promotion_conditions.create!(kind: 'min_quantity', quantity: 2)
    expect(Products::Quote.new(product:, promotion: owned).preview.discount).to eq(0)
  end
end
