FactoryBot.define do
  factory :sat_unit_key do
    code { Faker::Alphanumeric.alphanumeric(number: 3).upcase }
    description { Faker::Commerce.product_name }
    symbol { %w[kg m pza l hr].sample }

    valid_from { nil }
    valid_to { nil }

    deleted_at { nil }

    trait :with_valid_range do
      valid_from { Date.current - rand(1..10) }
      valid_to   { Date.current + rand(1..10) }
    end

    trait :expired do
      valid_from { Date.current - 10 }
      valid_to   { Date.current - 1 }
    end

    trait :future do
      valid_from { Date.current + 1 }
      valid_to   { Date.current + 10 }
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
