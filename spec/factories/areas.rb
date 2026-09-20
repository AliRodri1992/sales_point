FactoryBot.define do
  factory :area do
    sequence(:code) { |n| "area_#{n}" }
    sequence(:name) { |n| "Area #{n}" }
    status { 'active' }
    deleted_at { nil }
  end
end
