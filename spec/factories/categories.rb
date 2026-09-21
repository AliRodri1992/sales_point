FactoryBot.define do
  factory :category do
    sequence(:code) { |n| "category_#{n}" }
    sequence(:name) { |n| "Category #{n}" }
    status { 'active' }
    deleted_at { nil }
  end
end
