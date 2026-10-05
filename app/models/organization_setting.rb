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
            format: { with: /\A[A-Z]{3}\z/ },
            on: %i[create update]
  validates :timezone,
            presence: true,
            inclusion: { in: ONBOARDING_TIMEZONES },
            on: %i[create update]
  validates :payment_method,
            presence: true,
            inclusion: { in: payment_methods.keys },
            on: %i[create update]
  validates :organization_id,
            uniqueness: { conditions: -> { where(deleted_at: nil) } },
            on: %i[create update]

  scope :active_records, -> { where(deleted_at: nil) }
end
