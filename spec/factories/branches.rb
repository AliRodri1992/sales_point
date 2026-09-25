FactoryBot.define do
  factory :branch do
    name { 'Sucursal Centro' }
    address { 'Av. Reforma 100, Centro' }
    phone { '5551234567' }
    status { true }
    deleted_at { nil }
  end
end
