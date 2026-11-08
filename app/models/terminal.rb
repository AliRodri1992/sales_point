# frozen_string_literal: true

class Terminal < ApplicationRecord
  include RestrictsClosedBranchMutations
  belongs_to :branch

  enum :status, {
    active: 'active',
    inactive: 'inactive'
  }

  validate :branch_active_when_terminal_activated

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

  scope :active_records, -> { where(deleted_at: nil, status: :active) }

  private

  def branch_active_when_terminal_activated
    return unless active? && (new_record? || will_save_change_to_status?)

    return if branch&.operationally_active?
    return if branch&.preparing? && !branch.organization&.onboarding_completed?

    errors.add(:branch, :invalid)
  end
end
