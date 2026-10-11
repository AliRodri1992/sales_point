# frozen_string_literal: true

FactoryBot.define do
  factory :currency do
    sequence(:code) { |n| "X#{format('%02d', n).tr('0123456789', 'ABCDEFGHIJ')}" }
    sequence(:name) { |n| "Test Currency #{n}" }
    decimal_places { 2 }
    active { true }
  end
end
