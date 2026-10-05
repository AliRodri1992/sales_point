# frozen_string_literal: true

FactoryBot.define do
  factory :payment_integration do
    organization
    provider { 'card' }
    status { 'active' }

    trait :qr do
      provider { 'qr' }
    end

    trait :pending do
      status { 'pending' }
    end

    trait :inactive do
      status { 'inactive' }
    end
  end
end
