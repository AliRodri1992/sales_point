# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatFactorType < ApplicationRecord
  include SatCatalogValidity

  has_many :tax_rates,
           class_name: 'SatTaxRate',
           foreign_key: :factor_type,
           primary_key: :code,
           inverse_of: :factor_type_catalog,
           dependent: :restrict_with_exception

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, inclusion: { in: %w[Tasa Cuota Exento] }
end
