# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatPeriodicity < ApplicationRecord
  include SatCatalogValidity

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, format: { with: /\A\d{2}\z/ }
end
