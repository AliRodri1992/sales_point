# frozen_string_literal: true

FactoryBot.define do
  factory :demo_request do
    name { 'Test User' }
    email { 'test@example.com' }
    company { 'Test Company' }
    phone { '+525512345678' }
    business_type { 'grocery' }
    branches { 1 }
    message { 'Please show me a demo' }
    terms_accepted { true }
  end
end
