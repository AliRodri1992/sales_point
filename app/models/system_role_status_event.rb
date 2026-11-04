# frozen_string_literal: true

class SystemRoleStatusEvent < ApplicationRecord
  belongs_to :system_role, -> { with_deleted }, inverse_of: :status_events
  belongs_to :actor, -> { with_deleted }, class_name: 'User', inverse_of: false

  validates :from_status, :to_status, :reason, presence: true
  validates :reason, length: { maximum: 1000 }
  validates :from_status, :to_status, inclusion: { in: SystemRole.statuses.keys }

  def readonly?
    persisted?
  end

  before_destroy { throw :abort }
end
