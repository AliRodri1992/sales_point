# frozen_string_literal: true

class Country < ApplicationRecord
  has_many :country_currencies, dependent: :restrict_with_error
  has_many :currencies, through: :country_currencies

  before_validation :normalize_iso_codes

  validates :name, presence: true
  validates :iso_alpha2, presence: true, uniqueness: { conditions: -> { with_deleted } },
                         format: { with: /\A[A-Z]{2}\z/ }
  validates :iso_alpha3, presence: true, uniqueness: { conditions: -> { with_deleted } },
                         format: { with: /\A[A-Z]{3}\z/ }
  validates :iso_numeric, presence: true, uniqueness: { conditions: -> { with_deleted } },
                          format: { with: /\A\d{3}\z/ }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  private

  def normalize_iso_codes
    self.iso_alpha2 = iso_alpha2&.strip&.upcase
    self.iso_alpha3 = iso_alpha3&.strip&.upcase
    self.iso_numeric = iso_numeric&.strip
  end
end
