# frozen_string_literal: true

FactoryBot.define do
  factory :membership_plan_feature do
    membership_plan
    membership_feature
    enabled { true }
    limit { nil }
    value { Faker::Lorem.word }
    position { 0 }
    deleted_at { nil }
  end
end
