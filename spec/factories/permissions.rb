FactoryBot.define do
  factory :permission do
    sequence(:code) { |n| "module#{n}.access" }
    sequence(:name) { |n| "Permission #{n}" }
    sequence(:module_name) { |n| "Module #{n}" }
    status { :active }
  end
end
