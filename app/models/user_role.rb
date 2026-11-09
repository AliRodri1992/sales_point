# frozen_string_literal: true

class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :system_role
  belongs_to :branch, optional: true
  belongs_to :organization, optional: true

  validates :user_id,
            uniqueness: {
              scope: %i[system_role_id branch_id organization_id],
              conditions: -> { where(deleted_at: nil) }
            }

  before_validation :resolve_organization
  validate :organization_matches_branch
  validate :organization_required_for_membership
  validate :organization_membership_matches_user
  validate :branch_role_requires_branch
  validate :global_role_cannot_have_branch
  validate :assignable_role
  validate :no_new_assignments_to_closed_branch, if: :new_assignment?
  before_save :lock_assignable_role
  around_save :serialize_branch_assignment, if: :branch_assignment_change?

  scope :active, -> { joins(:system_role).where(deleted_at: nil, system_roles: { status: 'active', deleted_at: nil }) }

  private

  def resolve_organization
    return if organization_id.present?

    if branch
      self.organization = branch.organization
    elsif CurrentOrganizationAccess.organization
      self.organization = CurrentOrganizationAccess.organization
    elsif user&.persisted?
      memberships = user.organization_memberships.where(deleted_at: nil)
      self.organization_id = memberships.pick(:organization_id) if memberships.one?
    end
  end

  def organization_matches_branch
    return unless branch && organization_id != branch.organization_id

    errors.add(:organization, :invalid)
  end

  def organization_required_for_membership
    return unless new_assignment? && organization_id.nil? && user&.persisted?
    return unless user.organization_memberships.exists?(deleted_at: nil)

    errors.add(:organization, :blank)
  end

  def organization_membership_matches_user
    return unless new_assignment? && organization_id && user&.persisted?
    return if user.organization_memberships.where(deleted_at: nil).exists?(organization_id:)

    errors.add(:organization, :invalid)
  end

  def branch_assignment_change?
    branch_id.present? && new_assignment?
  end

  def serialize_branch_assignment
    locked_branch = Branch.with_deleted.find(branch_id)
    locked_branch.with_lock do
      if locked_branch.closed? || locked_branch.deleted_at.present?
        errors.add(:branch, :invalid)
        raise ActiveRecord::RecordInvalid, self
      end

      yield
    end
  end

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

  def no_new_assignments_to_closed_branch
    return unless branch && (branch.closed? || branch.deleted_at.present?)

    errors.add(:branch, :invalid)
  end

  def branch_role_requires_branch
    return unless system_role&.branch? && branch_id.blank?

    errors.add(:branch, I18n.t('user_role_errors.branch_required'))
  end

  def global_role_cannot_have_branch
    return unless system_role&.system? && branch_id.present?

    errors.add(:branch, I18n.t('user_role_errors.system_role_global'))
  end
end
