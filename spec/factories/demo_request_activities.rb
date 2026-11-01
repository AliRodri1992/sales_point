# frozen_string_literal: true

FactoryBot.define do
  factory :demo_request_activity do
    association :demo_request
    user { nil }
    action { 'created' }
    details { nil }
  end
end
