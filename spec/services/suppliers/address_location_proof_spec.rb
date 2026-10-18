# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::AddressLocationProof do
  let(:supplier) { create(:supplier) }
  let(:user) { create(:user) }
  let(:address) { build(:address, addressable: supplier) }
  let(:latitude) { 19.6742 }
  let(:longitude) { -99.1803 }
  let(:token) { described_class.issue(address:, supplier:, user:, latitude:, longitude:) }

  def verified(latitude: 19.675, longitude: -99.182, reason: nil, **options)
    described_class.verify(
      token:, address:, supplier:, user:, selection: { latitude:, longitude:, reason: }, **options
    )
  end

  it 'accepts a nearby user-adjusted marker' do
    expect(verified).to be true
  end

  it 'rejects a distant marker without a reason' do
    expect(verified(latitude: 20.0, longitude: -99.1803)).to be false
  end

  it 'requires a meaningful justification for distant adjustments' do
    expect(verified(latitude: 20.0, longitude: -99.1803, reason: 'wrong')).to be false
    expect(verified(latitude: 20.0, longitude: -99.1803,
                    reason: 'La entrada se encuentra en otra calle')).to be true
  end

  it 'rejects tampered or impossible coordinates' do
    expect(verified(latitude: 'invalid')).to be false
    expect(verified(latitude: 190.0)).to be false
    expect(described_class.verify(token: 'bad', address:, supplier:, user:,
                                  selection: { latitude:, longitude:, reason: nil })).to be false
  end

  it 'binds the proof to both the supplier and the operator' do
    other_supplier = create(:supplier)
    other_user = create(:user)
    options = { token:, address:, selection: { latitude:, longitude:, reason: nil } }
    expect(described_class.verify(**options, supplier: other_supplier, user:)).to be false
    expect(described_class.verify(**options, supplier:, user: other_user)).to be false
  end

  it 'invalidates the proof after an address change' do
    token
    address.street = 'Calle diferente'
    expect(verified).to be false
  end
end
