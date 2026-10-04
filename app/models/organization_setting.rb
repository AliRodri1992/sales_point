# frozen_string_literal: true

class OrganizationSetting < ApplicationRecord
  belongs_to :organization

  attribute :payment_method, :string

  enum :payment_method, {
    cash: 'cash',
    card: 'card',
    qr: 'qr'
  }

  ONBOARDING_CURRENCIES = %w[MXN USD JPY KRW].freeze
  ONBOARDING_TIMEZONES = %w[
    UTC
    America/Mexico_City
    America/Monterrey
    America/Tijuana
  ].freeze

  validates :currency,
            presence: true,
            inclusion: { in: ONBOARDING_CURRENCIES },
            format: { with: /\A[A-Z]{3}\z/ }
  validates :timezone,
            presence: true,
            inclusion: { in: ONBOARDING_TIMEZONES }
  validates :payment_method,
            presence: true,
            inclusion: { in: payment_methods.keys }
  validates :organization_id,
            uniqueness: { conditions: -> { where(deleted_at: nil) } }
end
