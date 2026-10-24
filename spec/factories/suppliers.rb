FactoryBot.define do
  factory :supplier do
    association :organization
    association :currency
    sequence(:code) { |n| format('SUP-%04d', n) }
    sequence(:name) { |n| "Proveedor #{n}" }
    sequence(:email) { |n| "proveedor#{n}@example.com" }
    # Three alphanumeric homoclave characters stay valid after sequence 999.
    sequence(:rfc) { |n| "XAXX010101#{n.to_s(36).upcase.rjust(3, '0')}" }
    person_type { 'individual' }
    phone { '5555555555' }
    status { :active }
    notes { nil }
    sat_fiscal_regime { nil }
    deleted_at { nil }

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
