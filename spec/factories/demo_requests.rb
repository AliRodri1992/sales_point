# frozen_string_literal: true

FactoryBot.define do
  factory :demo_request do
    name { 'Test User' }
    email { 'test@example.com' }
    company { 'Test Company' }
    phone { '+1234567890' }
    message { 'Please show me a demo' }
  end
end
