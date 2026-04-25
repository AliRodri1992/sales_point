FactoryBot.define do
  factory :system_role do
    name { Faker::Job.unique.position }
    role_type { SystemRole.role_types.keys.sample }
    status { SystemRole.statuses.keys.sample }
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
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
