FactoryBot.define do
  factory :sat_payment_method do
    code { format('%02d', rand(1..99)) }
    description { Faker::Commerce.product_name }

    valid_from { Faker::Date.backward(days: 10) }
    valid_to { Faker::Date.forward(days: 10) }

    status { true }
    deleted_at { nil }
  end
end
