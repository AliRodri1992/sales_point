# frozen_string_literal: true

class OrganizationMembership < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  enum :status, { active: 'active', inactive: 'inactive' }

  validates :user_id, uniqueness: {
    scope: :organization_id,
    conditions: -> { where(deleted_at: nil) }
  }
  validates :status, presence: true
end