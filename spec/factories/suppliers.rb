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
    status { :active }
    notes { nil }
    sat_fiscal_regime { nil }
    deleted_at { nil }

    after(:build) do |supplier|
      # Isolated model fixtures deliberately omit the full onboarding dossier.
      supplier.skip_primary_dossier_validation = true
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
