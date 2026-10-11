# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/currencies')
require Rails.root.join('db/seeds/countries')

RSpec.describe 'Country and currency seeds', type: :model do
  it 'loads all 249 ISO countries without duplication on repeated runs' do
    CurrencySeeds.seed!
    2.times { CountrySeeds.seed! }

    expect(Country.count).to eq(249)
    expect(Country.find_by!(iso_alpha2: 'MX').iso_alpha3).to eq('MEX')
    expect(Country.find_by!(iso_alpha2: 'KR').iso_numeric).to eq('410')
  end

  it 'loads MXN, USD and KRW with the correct decimal precision' do
    2.times { CurrencySeeds.seed! }

    expect(Currency.where(code: %w[MXN USD KRW]).count).to eq(3)
    expect(Currency.find_by!(code: 'MXN').decimal_places).to eq(2)
    expect(Currency.find_by!(code: 'USD').decimal_places).to eq(2)
    expect(Currency.find_by!(code: 'KRW').decimal_places).to eq(0)
  end

  it 'associates each starter country with its primary currency' do
    CurrencySeeds.seed!
    CountrySeeds.seed!

    { 'MX' => 'MXN', 'US' => 'USD', 'KR' => 'KRW' }.each do |country_code, currency_code|
      country = Country.find_by!(iso_alpha2: country_code)
      expect(country.country_currencies.find_by!(is_primary: true).currency.code).to eq(currency_code)
    end
  end

  it 'restores a previously soft-deleted currency rather than duplicating it' do
    CurrencySeeds.seed!
    currency = Currency.find_by!(code: 'MXN')
    currency.destroy!
    CurrencySeeds.seed!

    expect(Currency.find_by!(code: 'MXN').id).to eq(currency.id)
  end
end
