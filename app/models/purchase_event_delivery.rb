# frozen_string_literal: true

class PurchaseEventDelivery < ApplicationRecord
  belongs_to :organization
  belongs_to :recipient, class_name: 'User'

  validates :event_key, presence: true
end
