# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Products::SavePriceList do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, cost: 20) }
  let(:actor) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:list) { organization.price_lists.create!(name: 'Trade', currency: 'MXN') }

  before do
    create(:currency, code: 'MXN')
    create(:organization_membership, organization:, user: actor)
  end

  def save_rows(*rows, reason: nil, user: actor, **attributes)
    submitted = attributes.merge(price_list_items_attributes: rows)
    described_class.new(list:, actor: user, reason:, attributes: submitted).call
  end

  it 'retires persisted entries without deleting the price history and discards unsaved removals' do
    expect(save_rows({ product_id: product.id, price: 40 })).to be(true)
    item = list.price_list_items.sole
    change_id = item.price_change_events.sole.id
    expect(save_rows({ id: item.id, _destroy: '1' })).to be(false)
    expect(list.price_list_items.sole).to be_marked_for_destruction
    expect(list.reload.price_list_items.count).to eq(1)
    expect(save_rows({ id: item.id, _destroy: '1' }, { product_id: product.id, _destroy: '1' },
                     reason: 'End of contract')).to be(true)
    expect(list.reload.price_list_items).to be_empty
    expect(PriceListItem.with_deleted.find(item.id).deleted_at).to be_present
    expect(PriceChangeEvent.find(change_id).price_list_item_id).to eq(item.id)
    expect(FinancialAuditEvent.where(subject_type: 'PriceList', subject_id: list.id).last.details)
      .to include('price_list_item_id' => item.id, 'reason' => 'End of contract')
  end

  it 'rolls retirement back with other invalid edits' do
    expect(save_rows({ product_id: product.id, price: 40 })).to be(true)
    item = list.price_list_items.sole
    expect(save_rows({ id: item.id, _destroy: '1' }, name: '', reason: 'Correction')).to be(false)
    expect(list.price_list_items.sole).to be_marked_for_destruction
    expect(list.reload.price_list_items.sole).to eq(item)
    expect(FinancialAuditEvent.where(event: 'price_list.item_retired')).to be_empty
  end

  it 'requires a reason and records the previous dates when the validity of a historic row changes' do
    expect(save_rows({ product_id: product.id, price: 40 })).to be(true)
    item = list.price_list_items.sole
    boundary = 1.week.from_now.change(usec: 0)
    expect(save_rows({ id: item.id, ends_at: boundary })).to be(false)
    expect(list.errors[:price_change_reason]).to be_present
    expect(item.reload.ends_at).to be_nil
    expect(save_rows({ id: item.id, ends_at: boundary }, reason: 'Contract expires')).to be(true)
    event = FinancialAuditEvent.find_by!(event: 'price_list.item_period_changed', subject_id: list.id)
    expect(event.details).to include('price_list_item_id' => item.id, 'reason' => 'Contract expires')
    expect(event.details.fetch('changes').fetch('ends_at').first).to be_nil
  end

  it 'rejects a malformed reason without mutating historical financial data' do
    expect(save_rows({ product_id: product.id, price: 40 })).to be(true)
    item = list.price_list_items.sole
    expect(save_rows({ id: item.id, price: 50 }, reason: 123)).to be(false)
    expect(list.errors[:price_change_reason]).to be_present
    expect(item.reload.price).to eq(40)
  end

  it 'requires authorization for a price that rounds below cost at the catalog precision' do
    Currency.find_by!(code: 'MXN').update!(decimal_places: 0)
    product.update!(cost: '20.20')
    expect(save_rows({ product_id: product.id, price: '20.30' }, user: create(:user))).to be(false)
    expect(list.reload.price_list_items).to be_empty
  end

  it 'requires authorization when a period change reintroduces a below-cost row' do
    expect(save_rows({ product_id: product.id, price: 10, ends_at: 1.day.ago })).to be(true)
    item = list.price_list_items.sole
    user = create(:user)
    expect(save_rows({ id: item.id, ends_at: nil }, reason: 'Renewed', user:)).to be(false)
    expect(item.reload.ends_at).to be_present
  end

  it 'checks existing rows when extending the validity of the entire price list' do
    expect(save_rows({ product_id: product.id, price: 10 }, starts_at: 1.week.from_now)).to be(true)
    original = list.reload.starts_at
    expect(save_rows(user: create(:user), starts_at: nil)).to be(false)
    expect(list.reload.starts_at).to eq(original)
  end

  it 'authorizes below-cost prices in comparable currency and honors presentation units' do
    user = create(:user)
    box = product.product_presentations.create!(name: 'Box', units: 10)
    row = { product_id: product.id, product_presentation_id: box.id, price: 125 }
    expect(save_rows(row, user:)).to be(false)
    expect(list.reload.price_list_items).to be_empty
    expect(save_rows(row)).to be(true)
    expect(list.reload.price_list_items.sole.price).to eq(125)
  end
end
