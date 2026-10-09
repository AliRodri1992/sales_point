FactoryBot.define do
  factory :address do
    association :addressable, factory: %i[branch without_address]
    street { 'Av. Reforma' }
    exterior_number { '100' }
    interior_number { '446' }
    neighborhood { 'Centro' }
    city { 'Cuautitlán' }
    state { 'Estado de México' }
    country { 'MX' }
    postal_code { '54800' }

    latitude { 19.4326 }
    longitude { -99.1332 }

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
