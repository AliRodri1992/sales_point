FactoryBot.define do
  factory :language do
    sequence(:code) { |n| n.to_s(36).rjust(2, '0') }
    sequence(:name) { |n| "Language #{n}" }
    flag_iso { 'us' }
    status { 'active' }
    deleted_at { nil }
  end
end
