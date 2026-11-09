# frozen_string_literal: true

FactoryBot.define do
  factory :unit_of_measure do
    association :organization
    association :sat_unit_key
    sequence(:code) { |n| "UNIT_#{n}" }
    name { 'Unidad de prueba' }
    abbreviation { 'ud' }
    decimal_precision { 0 }
    status { 'active' }
  end
end
