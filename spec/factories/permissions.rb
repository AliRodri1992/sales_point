FactoryBot.define do
  factory :permission do
    sequence(:code) { |n| "module_#{n}.access" }
    sequence(:name) { |n| "Module #{n}" }
    module_name { 'module' }
    description { Faker::Lorem.sentence(word_count: 8) }
    status { :active }
  end
end
