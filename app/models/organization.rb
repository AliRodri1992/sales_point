# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :organization_memberships, dependent: :restrict_with_exception
  has_many :users, through: :organization_memberships
  has_many :employees, dependent: :restrict_with_exception
  has_many :branches, dependent: :restrict_with_exception
  has_many :organization_settings, dependent: :destroy
  has_many :payment_integrations, dependent: :restrict_with_exception
  has_many :organization_migrations, dependent: :restrict_with_exception
  has_many :onboarding_audits, dependent: :restrict_with_exception

  enum :status, { active: 'active', inactive: 'inactive', suspended: 'suspended' }
  enum :onboarding_status, { pending: 'pending', in_progress: 'in_progress', completed: 'completed' }

  ONBOARDING_BUSINESS_SECTORS = %w[grocery fashion restaurant pharmacy].freeze
  TAX_ID_FORMAT = /\A[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}\z/i

  validates :name, presence: true, length: { in: 2..150 }
  validates :tax_id,
            presence: true,
            length: { in: 12..13 },
            format: { with: TAX_ID_FORMAT },
            uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :business_sector,
            presence: true,
            inclusion: { in: ONBOARDING_BUSINESS_SECTORS }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :onboarding_status, presence: true, inclusion: { in: onboarding_statuses.keys }
  validates :onboarding_current_step,
            presence: true,
            numericality: { only_integer: true, in: 1..5 }

  scope :active_records, -> { where(deleted_at: nil, status: :active) }

  def start_onboarding!
    return if onboarding_status.in?(%w[in_progress completed])

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
    onboarding_status == 'completed'
  end
end
