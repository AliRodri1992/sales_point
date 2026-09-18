# frozen_string_literal: true

class MembershipPlanFeature < ApplicationRecord
  belongs_to :membership_plan
  belongs_to :membership_feature

  validates :membership_feature_id,
            uniqueness: { scope: :membership_plan_id }
  validates :limit,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :position,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
