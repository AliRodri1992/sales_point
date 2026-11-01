# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Purchases::Notify do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:order) do
    PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency, requested_by: user
    )
  end

  before { allow(user).to receive(:broadcast_notifications_refresh) }

  it 'delivers the same purchasing event only once' do
    expect do
      expect(described_class.call(record: order, action: 'order_submit', user:)).to be(true)
      expect(described_class.call(record: order, action: 'order_submit', user:)).to be(false)
    end.to change(PurchaseEventDelivery, :count).by(1)
       .and change(Noticed::Notification, :count).by(1)

    expect(user).to have_received(:broadcast_notifications_refresh).once
  end

  it 'preserves distinct approval and dispatch events' do
    described_class.call(record: order, action: 'order_approve', user:)
    described_class.call(record: order, action: 'order_dispatch', user:)

    expect(PurchaseEventDelivery.count).to eq(2)
  end
end
