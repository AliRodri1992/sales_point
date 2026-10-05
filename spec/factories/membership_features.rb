# frozen_string_literal: true

FactoryBot.define do
  factory :membership_feature do
    sequence(:name) { |n| "#{Faker::Commerce.product_name} Feature #{n}" }
    sequence(:key) { |n| "#{Faker::Internet.slug(words: 2, glue: '_')}_#{n}" }
    description { Faker::Lorem.sentence(word_count: 8) }
    value_type { :boolean }
    position { 0 }
    active { true }
    deleted_at { nil }
  end
end
