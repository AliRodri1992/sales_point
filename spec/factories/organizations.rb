FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:code) { |n| "ORG#{n}" }
    legal_name { name }
    tax_id { "AAA010101AAA" }
    email { Faker::Internet.unique.email }
    phone { '5555555555' }
    status { 'active' }
  end
end
