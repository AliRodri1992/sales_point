FactoryBot.define do
  factory :sat_currency do
    code { Faker::Currency.code.upcase }
    description { Faker::Currency.name }
    decimals { [0, 2, 3, 4, 5, 6, 8].sample }
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
