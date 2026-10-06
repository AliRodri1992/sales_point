FactoryBot.define do
  factory :landing_section do
    sequence(:key) { |n| "section_#{n}" }
    sequence(:position)
    enabled { true }
  end
end
