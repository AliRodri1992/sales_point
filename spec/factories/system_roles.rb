FactoryBot.define do
  factory :system_role do
    sequence(:name) { |n| "#{Faker::Job.position} #{n}" }
    code { name.parameterize(separator: '_') }
    role_type { SystemRole.role_types.keys.sample }
    status { :active }
    description { Faker::Lorem.sentence(word_count: 8) }

    trait :system do
      role_type { :system }
    end

    trait :branch do
      role_type { :branch }
    end

    trait :active do
      status { :active }
    end

    trait :inactive do
      status { :inactive }
    end

    trait :deprecated do
      status { :deprecated }
      deleted_at { Time.current }
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
