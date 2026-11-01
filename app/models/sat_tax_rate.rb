# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatTaxRate < ApplicationRecord
  include SatCatalogValidity

  belongs_to :tax_code_catalog,
             class_name: 'SatTaxCode',
             foreign_key: :tax_code,
             primary_key: :code,
             inverse_of: :rates,
             optional: true

  belongs_to :factor_type_catalog,
             class_name: 'SatFactorType',
             foreign_key: :factor_type,
             primary_key: :code,
             inverse_of: :tax_rates,
             optional: true

  validates :catalog_key, :description, presence: true
  validates :catalog_key, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :tax_code, :factor_type, :tax_type, presence: true
  validate :rate_range

  private

  def rate_range
    return if minimum_rate.nil? || maximum_rate.nil?

    errors.add(:maximum_rate, 'must be greater than or equal to minimum_rate') if maximum_rate < minimum_rate
  end
end
