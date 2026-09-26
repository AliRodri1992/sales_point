FactoryBot.define do
  factory :branch do
    name { 'Sucursal Centro' }
    phone { '5551234567' }
    status { true }
    deleted_at { nil }

    transient do
      without_address { false }
    end

    trait :without_address do
      transient do
        without_address { true }
      end
    end

    after(:build) do |branch, evaluator|
      unless evaluator.without_address || branch.address
        branch.build_address(
          street: 'Av. Reforma',
          exterior_number: '100',
          neighborhood: 'Centro',
          city: 'Cuautitlán',
          state: 'Estado de México',
          country: 'MX',
          postal_code: '54800'
        )
      end
    end
  end
end
