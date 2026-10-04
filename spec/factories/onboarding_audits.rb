# frozen_string_literal: true

FactoryBot.define do
  factory :onboarding_audit do
    association :organization
    association :user
    action { 'step_updated' }
    step { 1 }
    section { 'company' }
    metadata { { 'source' => 'onboarding' } }
  end
end
