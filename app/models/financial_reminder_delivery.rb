# frozen_string_literal: true

class FinancialReminderDelivery < ApplicationRecord
  belongs_to :organization
  belongs_to :account_payable
  belongs_to :recipient, class_name: 'User'
  validates :event_key, presence: true, uniqueness: true
end
