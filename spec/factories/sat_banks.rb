FactoryBot.define do
  factory :sat_bank do
    code { Faker::Number.unique.number(digits: 3).to_s.rjust(3, '0') }
    name { Faker::Bank.name }

    valid_from { Faker::Date.backward(days: 365) }
    valid_to   { Faker::Date.forward(days: 365) }

    status { true }
    deleted_at { nil }

    # =========================
    # TRAITS
    # =========================
    trait :inactive do
      status { false }
    end

    trait :deleted do
      deleted_at { Time.current }
    end

    trait :no_validity do
      valid_from { nil }
      valid_to   { nil }
    end

    trait :expired do
      valid_from { 2.years.ago.to_date }
      valid_to   { 1.year.ago.to_date }
    end

    trait :future do
      valid_from { 1.year.from_now.to_date }
      valid_to   { 2.years.from_now.to_date }
    end
  end
end
