FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    user_type { 'employee' }
    status { 'active' }
    theme { 'theme-material-red' }
  end
end
