FactoryBot.define do
  factory :employee do
    association :organization
    sequence(:first_name) { |n| "Employee#{n}" }
    sequence(:last_name) { |n| "User#{n}" }
    sequence(:email) { |n| "employee#{n}@example.com" }
    status { :active }
  end
end
