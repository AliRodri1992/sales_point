FactoryBot.define do
  factory :landing_section do
    sequence(:key) { |n| LandingSection::KEYS[(n - 1) % LandingSection::KEYS.length] }
    sequence(:position)
    enabled { true }
  end
end
