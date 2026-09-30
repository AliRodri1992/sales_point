FactoryBot.define do
  factory :translate do
    association :language
    sequence(:key) { |n| "test.key.#{n}" }
    sequence(:value) { |n| "Translation #{n}" }
    translation_source { 'manual' }
    deleted_at { nil }
  end
end
