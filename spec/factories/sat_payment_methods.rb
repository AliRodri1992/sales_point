FactoryBot.define do
  factory :sat_payment_method do
    sequence(:code) { |n| format('%02d', ((n - 1) % 99) + 1) }
    description { Faker::Commerce.product_name }

    valid_from { Faker::Date.backward(days: 10) }
    valid_to { Faker::Date.forward(days: 10) }

    status { true }
    deleted_at { nil }
  end
end
