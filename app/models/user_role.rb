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
  validate :assignable_role
  before_save :lock_assignable_role

  scope :active, -> { joins(:system_role).where(deleted_at: nil, system_roles: { status: 'active', deleted_at: nil }) }

  private

  def new_assignment?
    new_record? || will_save_change_to_system_role_id? || will_save_change_to_user_id? ||
      will_save_change_to_branch_id? || (will_save_change_to_deleted_at? && deleted_at.nil?)
  end

  def assignable_role
    return unless new_assignment? && system_role
    return if system_role.active? && system_role.deleted_at.nil?

    errors.add(:system_role, I18n.t('admin.system_roles.lifecycle.errors.not_assignable'))
  end

  def lock_assignable_role
    return unless system_role_id

    role = SystemRole.with_deleted.lock.find(system_role_id)
    return unless new_assignment? && (!role.active? || role.deleted_at.present?)

    errors.add(:system_role, I18n.t('admin.system_roles.lifecycle.errors.not_assignable'))
    raise ActiveRecord::RecordInvalid, self
  end

  def branch_role_requires_branch
    return unless system_role&.branch? && branch_id.blank?

    errors.add(:branch, 'is required for branch roles')
  end

  def global_role_cannot_have_branch
    return unless system_role&.system? && branch_id.present?

    errors.add(:branch, 'must be blank for system roles')
  end
end
