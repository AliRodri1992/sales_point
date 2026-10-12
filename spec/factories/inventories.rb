# frozen_string_literal: true

FactoryBot.define do
  factory :inventory do
    association :organization
    association :branch, organization: organization
    association :product, organization: organization
    stock { 0 }
    min_stock { 10 }
    max_stock { 500 }
  end
end
