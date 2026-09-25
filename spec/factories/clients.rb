FactoryBot.define do
  factory :client do
    sequence(:code) { |n| format('CLI-%04d', n) }
    sequence(:name) { |n| "Cliente #{n}" }
    sequence(:email) { |n| "cliente#{n}@example.com" }
    sequence(:rfc) { |n| "XAXX010101#{format('%03d', n)}" }

    phone { '5555555555' }
    postal_code { '06000' }
    credit_limit { 0 }
    status { :active }
    notes { nil }
    sat_fiscal_regime { nil }
    deleted_at { nil }

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
