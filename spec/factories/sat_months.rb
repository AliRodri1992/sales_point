FactoryBot.define do
  factory :sat_month do
    month_number { rand(1..12) }
    code { month_number.to_s.rjust(2, '0') }
    description { Faker::Date.month_name }

    status { true }
    valid_from { Date.current.beginning_of_year }
    valid_to { Date.current.end_of_year }
  end
end
