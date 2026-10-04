# frozen_string_literal: true

class OnboardingAudit < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  validates :action, presence: true, length: { maximum: 50 }
  validates :step, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :section, length: { maximum: 50 }, allow_blank: true
end
