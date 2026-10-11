# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Currency, type: :model do
  subject(:currency) { build(:currency) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to have_many(:country_currencies).dependent(:restrict_with_error) }
  it { is_expected.to have_many(:organizations).dependent(:restrict_with_error) }

  it 'normalizes currency codes' do
    currency.code = 'mxn'
    expect(currency).to be_valid
    expect(currency.code).to eq('MXN')
  end

  it 'rejects invalid precision and codes' do
    currency.decimal_places = 9
    currency.code = 'MX'
    expect(currency).not_to be_valid
    expect(currency.errors.attribute_names).to include(:decimal_places, :code)
  end

  it 'rejects duplicate codes for soft-deleted currencies' do
    existing = create(:currency)
    existing.destroy!
    currency.code = existing.code
    expect(currency).not_to be_valid
  end

  it 'soft deletes and restores a currency' do
    persisted = create(:currency)
    persisted.destroy!
    expect(described_class.find_by(id: persisted.id)).to be_nil
    persisted.restore!
    expect(described_class.find(persisted.id)).to eq(persisted)
  end

  it 'prevents removal of a currency used by an organization' do
    persisted = create(:currency)
    create(:organization, base_currency: persisted)
    expect(persisted.destroy).to be_falsey
  end
end
