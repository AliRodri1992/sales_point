# frozen_string_literal: true

FactoryBot.define do
  factory :membership_feature do
    sequence(:name) { |n| "Feature #{n}" }
    sequence(:key) { |n| "feature_#{n}" }
    description { 'A membership feature for testing.' }
    value_type { :boolean }
    position { 0 }
    active { true }
    deleted_at { nil }
  end
end
