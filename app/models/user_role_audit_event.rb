# frozen_string_literal: true

# Immutable record of a role grant or revocation performed through Users administration.
class UserRoleAuditEvent < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :actor, class_name: 'User'
  belongs_to :system_role
  belongs_to :branch, optional: true

  validates :action, inclusion: { in: %w[granted revoked] }
  before_update { throw :abort }
  before_destroy { throw :abort }

  def self.record!(user:, organization:, actor:, assignment:, action:)
    return unless actor

    create!(
      user:, organization:, actor:,
      system_role_id: assignment.system_role_id, branch_id: assignment.branch_id, action:
    )
  end
end
