# frozen_string_literal: true

FactoryBot.define do
  factory :inventory do
    association :organization
    branch { association(:branch, organization:) }
    product { association(:product, organization:) }
    stock { 0 }
    min_stock { 10 }
    max_stock { 500 }
  end
end
