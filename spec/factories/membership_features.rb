FactoryBot.define do
  factory :membership_feature do
    sequence(:name) { |n| "Feature #{n}" }
    sequence(:key) { |n| "feature_#{n}" }
    value_type { :boolean }
    position { 1 }
    active { true }
  end
end
