FactoryBot.define do
  factory :sat_payment_method_type do
    code { %w[PUE PPD].sample }
    description { Faker::Commerce.product_name }

    status { true }

    valid_from { Date.yesterday }
    valid_to { Date.tomorrow }

    created_at { Time.current }
    updated_at { Time.current }
  end
end
