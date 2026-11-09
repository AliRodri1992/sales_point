FactoryBot.define do
  factory :category do
    organization { CurrentOrganizationAccess.organization || Organization.first }
    sequence(:code) { |n| "category_#{n}" }
    sequence(:name) { |n| "Category #{n}" }
    status { 'active' }
    deleted_at { nil }
  end
end
