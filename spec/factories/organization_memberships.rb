FactoryBot.define do
  factory :organization_membership do
    association :organization
    association :user
    status { :active }
  end
end