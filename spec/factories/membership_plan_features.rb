FactoryBot.define do
  factory :membership_plan_feature do
    association :membership_plan
    association :membership_feature
    enabled { true }
    value { nil }
    limit { nil }
    position { 0 }
    deleted_at { nil }
  end
end
