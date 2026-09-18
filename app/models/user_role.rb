# frozen_string_literal: true

class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :system_role
  belongs_to :branch, optional: true

  validates :user_id,
            uniqueness: {
              scope: %i[system_role_id branch_id],
              conditions: -> { where(deleted_at: nil) }
            }

  validate :branch_role_requires_branch
  validate :global_role_cannot_have_branch

  scope :active, -> { joins(:system_role).where(deleted_at: nil, system_roles: { status: 'active' }) }

  private

  def branch_role_requires_branch
    return unless system_role&.branch? && branch_id.blank?

    errors.add(:branch, 'is required for branch roles')
  end

  def global_role_cannot_have_branch
    return unless system_role&.system? && branch_id.present?

    errors.add(:branch, 'must be blank for system roles')
  end
end
