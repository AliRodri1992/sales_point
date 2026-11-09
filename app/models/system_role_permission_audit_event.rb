# frozen_string_literal: true

class SystemRolePermissionAuditEvent < ApplicationRecord
  belongs_to :system_role, -> { with_deleted }, inverse_of: :permission_audit_events
  belongs_to :actor, -> { with_deleted }, class_name: 'User', inverse_of: false

  validate :at_least_one_permission_change
  before_destroy { throw :abort }

  def readonly?
    persisted?
  end

  private

  def at_least_one_permission_change
    return if added_permission_codes.any? || removed_permission_codes.any?

    errors.add(:base, :invalid)
  end
end
