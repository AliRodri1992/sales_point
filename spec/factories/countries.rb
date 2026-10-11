# frozen_string_literal: true

FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "Test Country #{n}" }
    sequence(:iso_alpha2) { |n| format('%02d', n).tr('0123456789', 'ABCDEFGHIJ') }
    sequence(:iso_alpha3) { |n| "X#{format('%02d', n).tr('0123456789', 'ABCDEFGHIJ')}" }
    sequence(:iso_numeric) { |n| format('%03d', n) }
    active { true }
  end
end
