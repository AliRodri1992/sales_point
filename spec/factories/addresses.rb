FactoryBot.define do
  factory :address do
    street { Faker::Address.street_name }
    exterior_number { Faker::Address.building_number }
    interior_number { Faker::Address.secondary_address }
    neighborhood { Faker::Address.community }
    city { Faker::Address.city }
    state { Faker::Address.state }
    country { 'MX' }
    postal_code { Faker::Address.zip_code }

    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }

    geocoding_status { :pending }

    trait :success do
      geocoding_status { :success }
    end

    trait :pending do
      geocoding_status { :pending }
    end

    trait :failed do
      geocoding_status { :failed }
    end
  end
end
