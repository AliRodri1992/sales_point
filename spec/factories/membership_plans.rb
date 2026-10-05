# frozen_string_literal: true

FactoryBot.define do
  factory :membership_plan do
    sequence(:name) { |n| "Plan #{n}" }
    sequence(:slug) { |n| "plan-#{n}" }
    description { 'A membership plan for testing.' }
    price { 99.00 }
    currency { 'MXN' }
    billing_interval { :monthly }
    trial_days { 0 }
    position { 0 }
    active { true }
    deleted_at { nil }
  end
end
