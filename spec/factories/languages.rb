FactoryBot.define do
  factory :language do
    sequence(:code) { |n| "l#{n}" }
    sequence(:name) { |n| "Language #{n}" }
    flag_iso { 'us' }
    status { 'active' }
    deleted_at { nil }
  end
end
