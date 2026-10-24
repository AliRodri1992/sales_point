# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assistant::GuideResponder do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:responder) { described_class.new(user:, organization:) }

  it 'does not expose procedures without an organization' do
    result = described_class.new(user:, organization: nil).call(question: 'Crear un producto')

    expect(result[:steps]).to be_empty
    expect(result[:source]).to eq('guide')
  end

  it 'does not expose procedures without a membership' do
    result = responder.call(question: 'Dar de alta un producto', context: 'products')

    expect(result[:steps]).to be_empty
  end

  it 'does not expose procedures after membership deactivation' do
    create(:organization_membership, organization:, user:, status: :inactive)

    expect(responder.call(question: 'Dar de alta un producto')[:steps]).to be_empty
  end

  it 'returns actionable help for an error within an active organization' do
    create(:organization_membership, organization:, user:)

    result = responder.call(question: 'No puedo guardar por un error')

    expect(result).to include(source: 'help', mood: 'concerned')
    expect(result[:steps]).not_to be_empty
  end

  it 'returns no invented steps when the question does not match any guide topic' do
    create(:organization_membership, organization:, user:)

    result = responder.call(question: 'zzzzxxxyyyqqq')

    expect(result[:steps]).to be_empty
    expect(result[:guide_url]).to eq('/admin/guide')
  end

  it 'requires category access for category procedures' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)

    expect(responder.send(:allowed?, 'categories')).to be(false)
    allow(user).to receive(:permission?).with('categories.access').and_return(true)
    expect(responder.send(:allowed?, 'categories')).to be(true)
  end

  it 'requires purchase and payable permissions for their respective modules' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)

    expect(responder.send(:allowed?, 'purchase_orders')).to be(false)
    expect(responder.send(:allowed?, 'payables')).to be(false)

    allow(user).to receive(:permission?).with('purchases.view').and_return(true)
    allow(user).to receive(:permission?).with('accounts_payable.view').and_return(true)

    expect(responder.send(:allowed?, 'purchase_orders')).to be(true)
    expect(responder.send(:allowed?, 'payables')).to be(true)
  end

  it 'denies supplier procedures without supplier listing permission' do
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:permission?).and_return(false)

    expect(responder.send(:allowed?, 'supplier_banks')).to be(false)
    expect(responder.send(:allowed?, 'supplier_calendar')).to be(false)
  end

  it 'does not hide public catalogue guide topics by default' do
    expect(responder.send(:allowed?, 'products')).to be(true)
  end
end
