FactoryBot.define do
  factory :system_role_permission do
    association :system_role
    association :permission
  end
end