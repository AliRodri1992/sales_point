FactoryBot.define do
  factory :sat_tax do
    sequence(:code) { |n| format('%03d', n % 999) }

    name { Faker::Commerce.material } # Ej: "Steel", "Plastic"

    tax_type { SatTax::TAX_TYPES.sample }
    factor_type { SatTax::FACTOR_TYPES.sample }

    applies_to { SatTax::APPLIES_TO.sample }

    priority { rand(0..5) }

    is_retainable { tax_type == 'withheld' }
    is_transferrable { tax_type == 'transfer' }

    description { Faker::Lorem.sentence }

    valid_from { Faker::Date.backward(days: 30) }
    valid_to { Faker::Date.forward(days: 30) }

    status { [true, false].sample }

    deleted_at { nil }

    trait :active do
      status { true }
      deleted_at { nil }
    end

    trait :deleted do
      deleted_at { Time.current }
    end

    trait :transfer do
      tax_type { 'transfer' }
      is_transferrable { true }
      is_retainable { false }
    end

    trait :withheld do
      tax_type { 'withheld' }
      is_retainable { true }
      is_transferrable { false }
    end

    trait :exempt do
      factor_type { 'exempt' }
    end
  end
end
