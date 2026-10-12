# frozen_string_literal: true

class SupplierEventDelivery < ApplicationRecord
  belongs_to :supplier
  belongs_to :recipient, class_name: 'User'

  validates :event_key, presence: true, uniqueness: true
end
