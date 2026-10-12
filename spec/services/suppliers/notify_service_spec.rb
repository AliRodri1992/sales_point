# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::NotifyService do
  let(:supplier) { create(:supplier) }
  let(:user) { create(:user) }

  before do
    allow(user).to receive(:broadcast_notifications_refresh)
  end

  it 'delivers a business event only once for the same version' do
    expect do
      expect(described_class.call(action: 'updated', supplier:, user:)).to be(true)
      expect(described_class.call(action: 'updated', supplier:, user:)).to be(false)
    end.to change(SupplierEventDelivery, :count).by(1)
       .and change(Noticed::Notification, :count).by(1)

    expect(user).to have_received(:broadcast_notifications_refresh).once
  end

  it 'delivers an event after the supplier changes again' do
    described_class.call(action: 'updated', supplier:, user:)
    supplier.update!(name: 'Updated supplier')

    expect(described_class.call(action: 'updated', supplier:, user:)).to be(true)
    expect(SupplierEventDelivery.count).to eq(2)
  end

  it 'distinguishes changes to different contacts of the same supplier' do
    first = create(:contact, contactable: supplier)
    second = create(:contact, contactable: supplier)

    expect(described_class.call(action: 'contact_created', supplier:, user:, subject: first)).to be(true)
    expect(described_class.call(action: 'contact_created', supplier:, user:, subject: second)).to be(true)
    expect(SupplierEventDelivery.count).to eq(2)
  end
end
