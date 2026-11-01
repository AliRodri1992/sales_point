FactoryBot.define do
  factory :organization_setting do
    association :organization
    association :base_currency, factory: :currency
    timezone { 'UTC' }
    payment_method { :cash }
  end
end
