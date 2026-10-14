# frozen_string_literal: true

FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "Test Country #{n}" }
    sequence(:iso_alpha2) { |n| "#{('A'.ord + ((n / 26) % 26)).chr}#{('A'.ord + (n % 26)).chr}" }
    sequence(:iso_alpha3) { |n| "X#{('A'.ord + ((n / 26) % 26)).chr}#{('A'.ord + (n % 26)).chr}" }
    sequence(:iso_numeric) { |n| format('%03d', n % 1000) }
    active { true }
  end
end
