# frozen_string_literal: true

FactoryBot.define do
  factory :membership_plan do
    sequence(:name) { |n| "#{Faker::Commerce.product_name} Plan #{n}" }
    sequence(:slug) { |n| "#{Faker::Internet.slug(words: 2)}-#{n}" }
    description { Faker::Lorem.sentence(word_count: 10) }
    price { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    currency { 'MXN' }
    billing_interval { :monthly }
    trial_days { 0 }
    position { 0 }
    active { true }
    deleted_at { nil }
  end
end
