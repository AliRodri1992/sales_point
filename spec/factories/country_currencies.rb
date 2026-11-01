# frozen_string_literal: true

FactoryBot.define do
  factory :country_currency do
    country
    currency
    active { true }
    is_primary { false }
  end
end
