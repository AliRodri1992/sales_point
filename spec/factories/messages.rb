# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    body { 'Test message' }
    conversation
    user

    trait :with_attachments do
      after(:create) do |message|
        create_list(:message_attachment, 1, message:)
      end
    end
  end
end
