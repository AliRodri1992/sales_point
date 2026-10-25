# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatNeighborhood < ApplicationRecord
  include SatCatalogValidity

  belongs_to :postal_code_catalog,
             class_name: 'SatPostalCode',
             foreign_key: :postal_code,
             primary_key: :code,
             inverse_of: :neighborhoods,
             optional: true

  validates :code, :description, presence: true
  validates :code, uniqueness: { scope: :postal_code, conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :postal_code, presence: true, format: { with: /\A\d{5}\z/ }
end
