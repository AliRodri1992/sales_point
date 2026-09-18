# frozen_string_literal: true

class MembershipFeature < ApplicationRecord
  has_many :membership_plan_features,
           dependent: :destroy
  has_many :membership_plans,
           through: :membership_plan_features

  enum :value_type,
       {
         boolean: 'boolean',
         integer: 'integer',
         decimal: 'decimal',
         text: 'text'
       },
       validate: true

  validates :name, presence: true, length: { in: 2..150 }
  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/ }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
