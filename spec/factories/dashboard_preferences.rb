FactoryBot.define do
  factory :dashboard_preference do
    association :user

    grid_type { %w[kpi main].sample }
    widget_id { "widget_#{Faker::Alphanumeric.alphanumeric(number: 8).downcase}" }

    position_x { Faker::Number.between(from: 0, to: 11) }
    position_y { Faker::Number.between(from: 0, to: 11) }
    width { Faker::Number.between(from: 1, to: 12) }
    height { Faker::Number.between(from: 1, to: 6) }
  end
end
