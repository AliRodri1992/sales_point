FactoryBot.define do
  factory :sat_currency do
    sequence(:code) { |n| %w[EUR GBP JPY CAD AUD].fetch((n - 1) % 5) }
    description { Faker::Currency.name }
    decimals { 2 }
    variation_percentage { Faker::Number.decimal(l_digits: 1, r_digits: 2) }
    symbol { Faker::Currency.symbol }

    trait :usd do
      code { 'USD' }
      description { 'US Dollar' }
      symbol { '$' }
      decimals { 2 }
    end

    trait :mxn do
      code { 'MXN' }
      description { 'Peso Mexicano' }
      symbol { '$' }
      decimals { 2 }
    end

    trait :eur do
      code { 'EUR' }
      description { 'Euro' }
      symbol { '€' }
      decimals { 2 }
    end
  end
end
