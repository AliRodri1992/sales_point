FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    user_type { 'employee' }
    status { 'active' }
    theme { 'theme-material-red' }

    # ApplicationController#set_locale overrides I18n.with_locale on every
    # request, so feature specs asserting English copy need a user whose
    # language is English.
    trait :english do
      association(:language, :english)
    end
  end
end
