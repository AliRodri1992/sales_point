# frozen_string_literal: true

class OrganizationMembership < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  enum :status, {
    active: 'active',
    inactive: 'inactive'
  }

  validates :user_id,
            uniqueness: {
              scope: :organization_id,
              conditions: -> { where(deleted_at: nil) }
            }
  enum :account_status, {
    pending: 'pending', active: 'active', suspended: 'suspended',
    blocked: 'blocked', deleted: 'deleted'
  }, prefix: :account

  scope :accessible, -> { active.where(account_status: 'active', deleted_at: nil) }

  after_create :scope_orphan_roles_on_first_membership

  validates :status, presence: true
  validates :account_status, presence: true

  private

  def scope_orphan_roles_on_first_membership
    return unless user.organization_memberships.where(deleted_at: nil).count == 1

    user.user_roles.where(branch_id: nil, organization_id: nil).update_all(organization_id:)
  end
end
