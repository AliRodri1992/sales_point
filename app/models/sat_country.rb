# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatCountry < ApplicationRecord
  include SatCatalogValidity

  has_many :states,
           class_name: 'SatState',
           foreign_key: :country_code,
           primary_key: :code,
           inverse_of: :country,
           dependent: :restrict_with_exception

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, format: { with: /\A[A-Z]{3}\z/ }
end
