# frozen_string_literal: true

class UserStatusEvent < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :actor, class_name: 'User'

  validates :from_status, :to_status, :reason, presence: true
end
