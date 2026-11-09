# frozen_string_literal: true

class Terminal < ApplicationRecord
  include RestrictsClosedBranchMutations
  belongs_to :branch

  enum :status, {
    active: 'active',
    inactive: 'inactive'
  }

  validate :branch_active_when_terminal_activated
  validate :branch_accepts_new_terminal, if: :new_or_reassigned?
  around_save :with_branch_lock, if: :branch_state_sensitive_change?

  validates :name, presence: true, length: { in: 2..80 }, on: %i[create update]
  validates :code,
            presence: true,
            length: { in: 2..40 },
            format: { with: /\A[A-Z0-9_-]+\z/ },
            uniqueness: {
              scope: :branch_id,
              conditions: -> { where(deleted_at: nil) }
            },
            on: %i[create update]
  validates :status,
            presence: true,
            inclusion: { in: statuses.keys },
            on: %i[create update]

  validates :name, presence: true, length: { in: 2..80 }, on: :onboardingstep3

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :active_records, -> { not_deleted.where(status: :active) }

  private

  def branch_state_sensitive_change?
    new_record? || will_save_change_to_status? || will_save_change_to_branch_id?
  end

  def with_branch_lock
    branch.with_lock do
      branch_accepts_new_terminal if new_or_reassigned?
      branch_active_when_terminal_activated
      raise ActiveRecord::RecordInvalid, self if errors[:branch].any?

      yield
    end
  end

  def new_or_reassigned?
    new_record? || will_save_change_to_branch_id?
  end

  def branch_accepts_new_terminal
    errors.add(:branch, :invalid) if branch&.suspended? || branch&.closed?
  end

  def branch_active_when_terminal_activated
    return unless active? && branch_state_sensitive_change?

    return if branch&.operationally_active?
    return if branch&.preparing? && branch.organization&.active? && !branch.organization.onboarding_completed?

    errors.add(:branch, :invalid)
  end
end
