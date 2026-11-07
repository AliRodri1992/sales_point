# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial transaction integrity' do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, price: 100) }
  let(:administrator) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:list) { organization.price_lists.create!(name: 'Retail', code: 'RETAIL', currency: 'MXN', status: 'active') }

  before do
    create(:currency, code: 'MXN')
    create(:organization_membership, user: administrator, organization:)
  end

  it 'uses the organization currency consistently for quotations and price authorizations' do
    dollar = create(:currency, code: 'USD')
    create(:organization_setting, organization:, base_currency: dollar)
    expect(Products::Quote.new(product:).call.currency).to eq('USD')
    writer = Products::SaveCatalogEntry.new(product:, actor: administrator,
                                            attributes: { price: 120, price_change_reason: 'Dollar supplier' })
    expect(writer.call).to be(true)
    expect(product.price_change_events.sole.currency).to eq('USD')
  end

  it 'rolls back a price change when its audit history cannot be persisted' do
    writer = Products::SaveCatalogEntry.new(product:, actor: administrator,
                                            attributes: { price: 120, price_change_reason: 'x' * 1001 })
    expect(writer.call).to be(false)
    expect(product.errors[:base]).to be_present
    expect(product.reload.price).to eq(100)
    expect(product.price_change_events).to be_empty
  end

  it 'does not request an invalid price or update a product that has been retired' do
    writer = Products::SaveCatalogEntry.new(product:, actor: administrator,
                                            attributes: { price: -1, price_change_reason: 'Invalid' })
    expect(writer.call).to be(false)
    expect(product.reload.price).to eq(100)
    product.update!(deleted_at: Time.current)
    expect { writer.call }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'rejects excessive line totals before applying a discount' do
    product.update!(price: 9_000_000_000)
    expect { Products::Quote.new(product:, quantity: 2).call }.to raise_error(ArgumentError, /total/)
  end

  it 'keeps all selected options and rule conditions in an idempotent redemption snapshot' do
    variant = product.product_variants.create!(name: 'Blue', sku: 'BLUE')
    presentation = product.product_presentations.create!(name: 'Box', units: 6)
    item = list.price_list_items.create!(product:, product_variant: variant, product_presentation: presentation,
                                         price: 510)
    offer = organization.promotions.create!(name: 'Wholesale', code: 'WHOLESALE', currency: 'MXN', status: 'active',
                                            promotion_conditions_attributes: [{ kind: 'min_quantity', quantity: 6 }],
                                            promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
    options = { product:, variant:, presentation:, price_list: list, quantity: 2,
                customer_segment: 'wholesale', customer_reference: 'CLIENT-1', idempotency_key: 'SALE-LINE-1' }
    redemption = Products::RedeemPromotion.new(**options).call
    expect(redemption.discount).to eq(102)
    expect(redemption.promotion).to eq(offer)
    expect(redemption.snapshot).to include('variant_id' => variant.id, 'presentation_id' => presentation.id,
                                           'price_list_id' => list.id, 'customer_segment' => 'wholesale')
    expect(redemption.snapshot['conditions'].sole).to include('kind' => 'min_quantity')
    expect(Products::RedeemPromotion.new(**options).call).to eq(redemption)
    expect(item.reload.price).to eq(510)
  end

  it 'rolls back list prices when the submitted audit reason is invalid' do
    item = list.price_list_items.create!(product:, price: 90)
    writer = Products::SavePriceList.new(list:, actor: administrator, reason: 'x' * 1001,
                                         attributes: { price_list_items_attributes: [{ id: item.id, price: 80 }] })
    expect(writer.call).to be(false)
    expect(list.errors[:base]).to be_present
    expect(item.reload.price).to eq(90)
    expect(item.price_change_events).to be_empty
  end

  it 'preserves list validation errors without creating a price change event' do
    writer = Products::SavePriceList.new(list:, actor: administrator, attributes: { name: '' })
    expect(writer.call).to be(false)
    expect(list.errors[:name]).to be_present
    expect(list.reload.name).to eq('Retail')
  end

  it 'changes list descriptions without inventing a price change when its items are unchanged' do
    item = list.price_list_items.create!(product:, price: 90)
    writer = Products::SavePriceList.new(list:, actor: administrator, attributes: { name: 'Revised retail' })
    expect(writer.call).to be(true)
    expect(item.price_change_events).to be_empty
    expect(item.reload.price).to eq(90)
  end

  it 'reports a database price-period conflict while propagating unrelated database failures' do
    error = ActiveRecord::StatementInvalid.new('Conflicting price periods')
    allow(error).to receive(:cause).and_return(PG::ExclusionViolation.new('overlap'))
    allow(list).to receive(:save!).and_raise(error)
    writer = Products::SavePriceList.new(list:, actor: administrator, attributes: {})
    expect(writer.call).to be(false)
    expect(list.errors[:base]).to include(I18n.t('admin.catalog_design.overlapping_price'))
    allow(list).to receive(:save!).and_raise(ActiveRecord::StatementInvalid, 'Storage unavailable')
    expect { writer.call }.to raise_error(ActiveRecord::StatementInvalid, 'Storage unavailable')
  end

  it 'rejects orphaned commercial options rather than inferring another product or organization' do
    records = [ProductVariant.new(name: 'Orphan'), ProductPresentation.new(name: 'Orphan', units: 1),
               ProductBarcode.new(value: 'ORPHAN', primary: true), PriceListItem.new(product:, price: 10),
               PromotionCondition.new(kind: 'min_quantity', quantity: 1),
               PromotionBenefit.new(kind: 'percentage', value: 10)]
    records.each do |record|
      expect(record).not_to be_valid
      expect(record.errors).to be_present
    end
  end

  it 'requires an approver and the same product as a referenced list item' do
    other = create(:product, organization:)
    item = list.price_list_items.create!(product: other, price: 90)
    event = product.price_change_events.build(organization:, actor: administrator, price_list_item: item,
                                              new_price: 90, currency: 'MXN', reason: 'Invalid approval',
                                              status: 'approved')
    expect(event).not_to be_valid
    expect(event.errors[:price_list_item]).to be_present
    expect(event.errors[:approved_by]).to be_present
  end

  it 'rejects a reviewed request and an administrator whose organization access was revoked' do
    event = product.price_change_events.create!(organization:, actor: administrator, previous_price: 100,
                                                new_price: 120, currency: 'MXN', reason: 'Pending review')
    administrator.organization_memberships.each { |membership| membership.update!(status: 'inactive') }
    expect { Products::DecidePriceChange.new(event:, actor: administrator, decision: 'approved').call }
      .to raise_error(Pundit::NotAuthorizedError)
    administrator.organization_memberships.each { |membership| membership.update!(status: 'active') }
    Products::DecidePriceChange.new(event:, actor: administrator, decision: 'rejected').call
    expect { Products::DecidePriceChange.new(event:, actor: administrator, decision: 'approved').call }
      .to raise_error(Products::DecidePriceChange::StalePrice)
  end
end
