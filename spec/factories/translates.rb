FactoryBot.define do
  factory :translate do
    association :language
    sequence(:key) { |n| "translation.key.#{n}" }
    sequence(:value) { |n| "Translation #{n}" }
    deleted_at { nil }
  end
end
