FactoryBot.define do
  factory :contact do
    association :contactable, factory: :organization
    sequence(:name) { |n| "Contact #{n}" }
    email { 'contact@example.com' }
    phone { '5555555555' }
    primary { false }
    active { true }

    trait :primary do
      primary { true }
    end

    trait :deleted do
      deleted_at { Time.current }
    end

    trait :inactive do
      active { false }
    end
  end
end
