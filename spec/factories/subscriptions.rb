FactoryBot.define do
  factory :subscription do
    association :organization
    association :membership_plan
    status { :active }
    starts_at { Time.current }
    ends_at { nil }
    trial_ends_at { nil }
    canceled_at { nil }
  end
end
