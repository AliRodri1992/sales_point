# frozen_string_literal: true

FactoryBot.define do
  factory :membership_feature do
    sequence(:name) { |n| "Feature #{Faker::Commerce.product_name} #{n}" }
    sequence(:key) { |n| "feature_#{n}" }
    description { Faker::Lorem.sentence(word_count: 8) }
    value_type { :boolean }
    position { 0 }
    active { true }
    deleted_at { nil }
  end
end
