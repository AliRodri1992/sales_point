FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:code) { |n| "ORG#{n}" }
    legal_name { name }
    sequence(:tax_id) { |n| "AAA0101#{format('%03d', n)}" }
    email { Faker::Internet.unique.email }
    phone { '5555555555' }
    status { 'active' }
  end
end
