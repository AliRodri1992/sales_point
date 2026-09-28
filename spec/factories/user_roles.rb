FactoryBot.define do
  factory :user_role do
    association :user
    association :system_role
    branch { nil }
  end
end
