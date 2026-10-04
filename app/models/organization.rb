# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :organization_memberships, dependent: :restrict_with_exception
  has_many :users, through: :organization_memberships
  has_many :employees, dependent: :restrict_with_exception
  has_many :branches, dependent: :restrict_with_exception
  has_many :organization_settings, dependent: :destroy
  has_many :payment_integrations, dependent: :restrict_with_exception
  has_many :organization_migrations, dependent: :restrict_with_exception

  enum :status, { active: 'active', inactive: 'inactive', suspended: 'suspended' }
  enum :onboarding_status, { pending: 'pending', in_progress: 'in_progress', completed: 'completed' }

  validates :name, presence: true, length: { in: 2..150 }
  validates :tax_id, presence: true, length: { in: 12..13 },
            format: { with: /\A[A-Z0-9]+\z/i },
            uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :business_sector, presence: true, length: { maximum: 50 }
  validates :status, presence: true
  validates :onboarding_status, presence: true
  validates :onboarding_current_step,
            numericality: { only_integer: true, in: 1..5 }

  scope :active_records, -> { where(deleted_at: nil, status: :active) }

  def start_onboarding!
    return if completed?

    update!(onboarding_status: :in_progress)
  end

  def complete_onboarding!
    update!(
      onboarding_status: :completed,
      onboarding_completed_at: Time.current,
      onboarding_current_step: 5
    )
  end

  def onboarding_completed?
    onboarding_status_completed?
  end
end
