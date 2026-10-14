FactoryBot.define do
  factory :sat_fiscal_regime do
    sequence(:code) { |n| format('%03d', 100 + n) }
    description { Faker::Company.bs }
    person_type { %w[F M].sample }

    valid_from { Time.zone.today - rand(10).days }
    valid_to   { Time.zone.today + rand(10).days }

    deleted_at { nil }
  end
end
