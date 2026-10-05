# frozen_string_literal: true

FactoryBot.define do
  factory :organization_migration do
    organization
    volume { :small }
    priority { :catalog }
    status { :pending }
    deleted_at { nil }
  end
end
