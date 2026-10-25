# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatPostalCode < ApplicationRecord
  include SatCatalogValidity

  has_many :neighborhoods,
           class_name: 'SatNeighborhood',
           foreign_key: :postal_code,
           primary_key: :code,
           inverse_of: :postal_code_catalog,
           dependent: :restrict_with_exception

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, format: { with: /\A\d{5}\z/ }
end
