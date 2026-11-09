# frozen_string_literal: true

class SystemRolePermissionAuditEvent < ApplicationRecord
  belongs_to :system_role, -> { with_deleted }, inverse_of: :permission_audit_events
  belongs_to :actor, -> { with_deleted }, class_name: 'User', inverse_of: false, optional: true

  validates :source, inclusion: { in: %w[user system] }
  validate :source_actor_consistency

  validate :at_least_one_permission_change
  before_destroy { throw :abort }

  def readonly?
    persisted?
  end

  private

  def source_actor_consistency
    return if (source == 'user' && actor_id.present?) || (source == 'system' && actor_id.nil?)

    errors.add(:source, :invalid)
  end

  def at_least_one_permission_change
    return if added_permission_codes.any? || removed_permission_codes.any?

    errors.add(:base, :invalid)
  end
end
