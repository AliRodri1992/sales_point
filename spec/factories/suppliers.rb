FactoryBot.define do
  factory :supplier do
    sequence(:code) { |n| format('SUP-%04d', n) }
    sequence(:name) { |n| "Proveedor #{n}" }
    sequence(:email) { |n| "proveedor#{n}@example.com" }
    sequence(:rfc) { |n| "XAXX010101#{format('%03d', n)}" }
    phone { '5555555555' }
    postal_code { '06000' }
    status { :active }
    notes { nil }
    sat_fiscal_regime { nil }
    deleted_at { nil }

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
