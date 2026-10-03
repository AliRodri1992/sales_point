FactoryBot.define do
  factory :organization_setting do
    association :organization
    currency { 'MXN' }
    timezone { 'UTC' }
    payment_method { :cash }
  end
end
