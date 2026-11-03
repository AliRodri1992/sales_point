# frozen_string_literal: true

class UserSecurityIncident < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :opened_by, class_name: 'User'
  belongs_to :resolved_by, class_name: 'User', optional: true

  validates :description, presence: true, length: { maximum: 1000 }
  validates :resolution, presence: true, if: :resolved_at?
end
