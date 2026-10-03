FactoryBot.define do
  factory :terminal do
    association :branch
    sequence(:name) { |n| "Register #{n}" }
    sequence(:code) { |n| "POS-#{format('%03d', n)}" }
    status { :active }
  end
end
