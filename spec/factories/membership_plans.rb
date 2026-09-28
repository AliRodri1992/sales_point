FactoryBot.define do
  factory :membership_plan do
    sequence(:name) { |n| "Plan #{n}" }
    sequence(:slug) { |n| "plan-#{n}" }
    description { 'Test membership plan' }
    price { 299.00 }
    currency { 'MXN' }
    billing_interval { :monthly }
    trial_days { 14 }
    position { 1 }
    active { true }
  end
end
