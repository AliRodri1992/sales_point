# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CountryCurrency, type: :model do
  subject(:country_currency) { build(:country_currency) }

  it { is_expected.to belong_to(:country) }
  it { is_expected.to belong_to(:currency) }

  it 'does not allow a primary currency to be inactive' do
    country_currency.is_primary = true
    country_currency.active = false
    expect(country_currency).not_to be_valid
    expect(country_currency.errors[:is_primary]).to be_present
  end

  it 'prevents duplicate country and currency pairs' do
    existing = create(:country_currency)
    country_currency.country = existing.country
    country_currency.currency = existing.currency
    expect(country_currency).not_to be_valid
  end

  it 'enforces only one primary currency per country at database level' do
    existing = create(:country_currency, is_primary: true)
    other = build(:country_currency, country: existing.country, is_primary: true)
    expect { other.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
