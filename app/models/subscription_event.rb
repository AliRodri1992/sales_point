# frozen_string_literal: true

class SubscriptionEvent < ApplicationRecord
  belongs_to :subscription
  belongs_to :membership_plan, optional: true
  belongs_to :from_membership_plan, class_name: 'MembershipPlan', optional: true
  belongs_to :to_membership_plan, class_name: 'MembershipPlan', optional: true
  belongs_to :performed_by, class_name: 'User', optional: true

  validates :event_type, presence: true, length: { maximum: 40 }
end
