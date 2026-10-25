# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatState < ApplicationRecord
  include SatCatalogValidity

  belongs_to :country,
             class_name: 'SatCountry',
             foreign_key: :country_code,
             primary_key: :code,
             inverse_of: :states,
             optional: true

  validates :code, :description, presence: true
  validates :code, uniqueness: { scope: :country_code, conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :country_code, presence: true
end
