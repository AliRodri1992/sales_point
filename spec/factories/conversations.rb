# frozen_string_literal: true

FactoryBot.define do
  factory :conversation do
    conversation_type { 'direct' }

    trait :direct do
      conversation_type { 'direct' }
    end
  end
end
