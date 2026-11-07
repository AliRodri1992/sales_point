# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Product price authorization' do
  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, price: 100) }
  let(:operator) { create(:user) }
  let(:administrator) do
    role = create(:system_role, :system, code: 'administrator')
    create(:user, system_roles: [role])
  end

  before { create(:organization_membership, organization:, user: administrator) }

  def save_entry(actor:, **attributes)
    Products::SaveCatalogEntry.new(product:, actor:, attributes:).call
  end

  it 'requires a reason, preserving the submitted form on validation errors' do
    expect(save_entry(actor: administrator, price: 120)).to be(false)
    expect(product.errors[:price_change_reason]).to be_present
    expect(product.reload.price).to eq(100)
    expect(product.price_change_events).to be_empty
  end

  it 'approves administrator changes atomically and records their immutable history' do
    expect(save_entry(actor: administrator, price: 120, price_change_reason: 'New supplier cost')).to be(true)
    event = product.price_change_events.last
    expect(event).to have_attributes(status: 'approved', previous_price: 100, new_price: 120,
                                     approved_by: administrator, currency: 'MXN')
    expect(event.update(reason: 'Rewritten')).to be(false)
    expect(event.destroy).to be(false)
    expect(product.reload.price).to eq(120)
  end

  it 'keeps the current price until an administrator reviews an operator request' do
    expect(save_entry(actor: operator, price: 120, price_change_reason: 'Supplier adjustment',
                      name: 'Updated')).to be(true)
    event = product.price_change_events.last
    expect(event).to be_pending
    expect(product.reload.price).to eq(100)
    expect(product.name).to eq('Updated')
    Products::DecidePriceChange.new(event:, actor: administrator, decision: 'approved').call
    expect(product.reload.price).to eq(120)
    expect(event.reload).to be_approved
  end

  it 'rejects stale approval and unauthorized decisions without changing prices' do
    save_entry(actor: operator, price: 120, price_change_reason: 'Adjust')
    event = product.price_change_events.last
    expect { Products::DecidePriceChange.new(event:, actor: operator, decision: 'approved').call }
      .to raise_error(Pundit::NotAuthorizedError)
    product.update!(price: 110)
    expect { Products::DecidePriceChange.new(event:, actor: administrator, decision: 'approved').call }
      .to raise_error(Products::DecidePriceChange::StalePrice)
    Products::DecidePriceChange.new(event:, actor: administrator, decision: 'rejected').call
    expect(product.reload.price).to eq(110)
    expect(event.reload).to be_rejected
  end

  it 'records the initial price in the same transaction as a new product' do
    record = Product.new(organization:)
    writer = Products::SaveCatalogEntry.new(product: record, actor: operator,
                                            attributes: { name: 'Coffee', code: 'COFFEE', price: 25 })
    expect(writer.call).to be(true)
    expect(record.price_change_events.last).to have_attributes(new_price: 25, status: 'approved')
  end
  it 'retains the identities in approved history when an account is archived' do
    save_entry(actor: administrator, price: 125, price_change_reason: 'Reviewed price')
    event_id = product.price_change_events.last.id
    administrator.update!(deleted_at: Time.current)
    event = PriceChangeEvent.find(event_id)
    expect(event.actor.id).to eq(administrator.id)
    expect(event.approved_by.id).to eq(administrator.id)
  end
end
