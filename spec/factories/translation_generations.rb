FactoryBot.define do
  factory :translation_generation do
    association :language
    association :source_language, factory: :language
    association :actor, factory: :user
    provider { 'libretranslate' }
    provider_configuration_version { 'test-version' }
    sequence(:source_catalog_version) { |n| "catalog-#{n}" }
    status { 'pending' }
  end
end
