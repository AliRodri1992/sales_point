# frozen_string_literal: true

FactoryBot.define do
  factory :currency do
    sequence(:code) { |n| "X#{(n % 676).divmod(26).map { |part| (65 + part).chr }.join}" }
    sequence(:name) { |n| "Test Currency #{n}" }
    decimal_places { 2 }
    active { true }
  end
end
