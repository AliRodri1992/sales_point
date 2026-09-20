FactoryBot.define do
  factory :sat_fiscal_regime do
    code { Faker::Number.number(digits: 3).to_s }
    description { Faker::Company.bs }
    person_type { %w[F M].sample }

    valid_from { Time.zone.today - rand(10).days }
    valid_to   { Time.zone.today + rand(10).days }

    deleted_at { nil }
  end
end
