FactoryBot.define do
  factory :branch do
    name { 'Sucursal Centro' }
    phone { '5551234567' }
    status { true }
    deleted_at { nil }

    after(:build) do |branch|
      branch.build_address(
        street: 'Av. Reforma',
        exterior_number: '100',
        neighborhood: 'Centro',
        city: 'Cuautitlán',
        state: 'Estado de México',
        country: 'MX',
        postal_code: '54800'
      ) unless branch.address
    end
  end
end
