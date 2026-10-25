# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatMunicipality < ApplicationRecord
  include SatCatalogValidity

  validates :code, :description, presence: true
  validates :code, uniqueness: { scope: :state_code, conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :state_code, presence: true
  validates :code, format: { with: /\A\d{3}\z/ }
end
