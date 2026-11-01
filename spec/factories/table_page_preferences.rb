FactoryBot.define do
  factory :table_page_preference do
    association :user
    association :organization
    table_key { 'suppliers' }
    per_page { 10 }
  end
end
