# frozen_string_literal: true

class MembershipPlan < ApplicationRecord
  has_many :membership_plan_features,
           dependent: :destroy
  has_many :membership_features,
           through: :membership_plan_features

  enum :billing_interval,
       {
         monthly: 'monthly',
         yearly: 'yearly'
       },
       validate: true

  validates :name, presence: true, length: { in: 2..100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :trial_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
