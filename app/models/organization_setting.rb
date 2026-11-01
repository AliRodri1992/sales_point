# frozen_string_literal: true

class OrganizationSetting < ApplicationRecord
  belongs_to :organization
  belongs_to :base_currency, class_name: 'Currency'

  validate :base_currency_must_be_active, on: %i[create update onboardingstep1]

  attribute :payment_method, :string

  enum :payment_method, {
    cash: 'cash',
    card: 'card',
    qr: 'qr'
  }

  ONBOARDING_TIMEZONES = %w[
    UTC
    America/Mexico_City
    America/Monterrey
    America/Tijuana
  ].freeze

  validates :timezone,
            presence: true,
            inclusion: { in: ONBOARDING_TIMEZONES },
            on: %i[create update]
  validates :default_table_page_size,
            inclusion: { in: TablePagePreference::OPTIONS },
            on: %i[create update]

  validates :payment_method,
            presence: true,
            inclusion: { in: payment_methods.keys },
            on: %i[create update]
  validates :organization_id,
            uniqueness: { conditions: -> { where(deleted_at: nil) } },
            on: %i[create update]

  validates :timezone,
            presence: true,
            inclusion: { in: ONBOARDING_TIMEZONES },
            on: :onboardingstep1
  validates :payment_method,
            presence: true,
            inclusion: { in: payment_methods.keys },
            on: :onboardingstep4

  scope :active_records, -> { where(deleted_at: nil) }

  private

  def base_currency_must_be_active
    return if base_currency.blank? || base_currency.active?

    errors.add(:base_currency, :invalid)
  end
end
