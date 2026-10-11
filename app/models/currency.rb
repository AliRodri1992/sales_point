# frozen_string_literal: true

class Currency < ApplicationRecord
  has_many :country_currencies, dependent: :restrict_with_error
  has_many :countries, through: :country_currencies
  has_many :organization_settings, foreign_key: :base_currency_id, inverse_of: :base_currency,
                                   dependent: :restrict_with_error

  before_validation :normalize_code

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { conditions: -> { with_deleted } },
                   format: { with: /\A[A-Z]{3}\z/ }
  validates :numeric_code, format: { with: /\A\d{3}\z/ }, allow_nil: true
  validates :decimal_places, numericality: { only_integer: true, in: 0..8 }

  scope :active, -> { where(active: true) }

  private

  def normalize_code
    self.code = code&.strip&.upcase
  end
end
