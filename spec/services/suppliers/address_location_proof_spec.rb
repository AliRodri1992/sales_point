# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::AddressLocationProof do
  let(:supplier) { create(:supplier) }
  let(:user) { create(:user) }
  let(:address) { build(:address, addressable: supplier) }
  let(:latitude) { 19.6742 }
  let(:longitude) { -99.1803 }
  let(:token) { described_class.issue(address:, supplier:, user:, coordinates: { latitude:, longitude: }) }

  def verified(latitude: 19.675, longitude: -99.182, reason: nil, reviewed: nil, **options)
    described_class.verify(
      token:, address:, supplier:, user:, selection: { latitude:, longitude:, reason:, reviewed: }, **options
    )
  end

  it 'accepts a nearby user-adjusted marker' do
    expect(verified).to be true
  end

  it 'rejects a distant marker without a reason' do
    expect(verified(latitude: 20.0, longitude: -99.1803)).to be false
  end

  it 'requires a meaningful justification for distant adjustments' do
    expect(verified(latitude: 19.75, longitude: -99.1803, reason: 'wrong', reviewed: '1')).to be false
    expect(verified(latitude: 19.75, longitude: -99.1803,
                    reason: 'La entrada se encuentra en otra calle', reviewed: '1')).to be true
  end

  it 'blocks even justified markers farther than 25 km' do
    expect(verified(latitude: 20.0, longitude: -99.1803,
                    reason: 'El acceso se encuentra muy lejos', reviewed: '1')).to be false
  end

  it 'requires explicit review for a move over 2 km' do
    expect(verified(latitude: 19.75, longitude: -99.1803,
                    reason: 'Acceso alterno a la bodega')).to be false
  end

  context 'with a low-confidence proposal' do
    let(:token) do
      described_class.issue(address:, supplier:, user:,
                            coordinates: { latitude:, longitude:, confidence: 0.35 })
    end

    it 'requires a justification and explicit verification even at suggested coordinates' do
      expect(verified(latitude:, longitude:)).to be false
      expect(verified(latitude:, longitude:, reviewed: '1')).to be false
      expect(verified(latitude:, longitude:, reason: 'Acceso cotejado físicamente',
                      reviewed: '1')).to be true
    end

    it 'preserves signed provider confidence for audit' do
      expect(described_class.confidence(token:, address:, supplier:, user:)).to eq(0.35)
    end
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

  it 'does not disclose confidence for a forged proposal token' do
    expect(described_class.confidence(token: 'malformed', address:, supplier:, user:)).to be_nil
  end

  it 'rejects longitude values outside the geographic limits' do
    expect(verified(longitude: -190)).to be(false)
  end

  it 'rejects a review reason longer than the permitted limit' do
    expect(verified(latitude: 19.75, longitude: -99.1803, reason: 'x' * 251, reviewed: '1'))
      .to be(false)
  end
end
