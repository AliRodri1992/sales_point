# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Country, type: :model do
  subject(:country) { build(:country) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to have_many(:country_currencies).dependent(:restrict_with_error) }
  it { is_expected.to have_many(:currencies).through(:country_currencies) }

  it 'normalizes ISO codes before validation' do
    country.iso_alpha2 = 'mx'
    country.iso_alpha3 = 'mex'
    expect(country).to be_valid
    expect(country.iso_alpha2).to eq('MX')
    expect(country.iso_alpha3).to eq('MEX')
  end

  it 'rejects invalid ISO codes' do
    country.iso_alpha2 = 'MEX'
    country.iso_numeric = '12A'
    expect(country).not_to be_valid
    expect(country.errors.attribute_names).to include(:iso_alpha2, :iso_numeric)
  end

  it 'rejects duplicate ISO codes even for soft-deleted countries' do
    existing = create(:country)
    existing.destroy!
    country.iso_alpha2 = existing.iso_alpha2
    expect(country).not_to be_valid
  end

  it 'soft deletes and restores a country' do
    persisted = create(:country)
    persisted.destroy!
    expect(described_class.find_by(id: persisted.id)).to be_nil
    expect(described_class.with_deleted.find(persisted.id)).to eq(persisted)
    persisted.restore!
    expect(described_class.find(persisted.id)).to eq(persisted)
  end

  it 'restricts deletion when associated currencies exist' do
    persisted = create(:country)
    create(:country_currency, country: persisted)
    expect(persisted.destroy).to be_falsey
    expect(persisted.errors).to be_present
  end
end
