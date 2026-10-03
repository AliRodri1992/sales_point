FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:tax_id) { |n| "ABC#{format('%09d', n)}" }
    business_sector { 'grocery' }
    status { :active }

    trait :with_settings do
      after(:create) do |organization|
        create(:organization_setting, organization:)
      end
    end
  end
end