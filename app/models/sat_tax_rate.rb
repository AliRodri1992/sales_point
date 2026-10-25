# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog; historical records remain available with_deleted.
class SatTaxRate < ApplicationRecord
  belongs_to :tax_code_catalog, class_name: 'SatTaxCode', foreign_key: :tax_code, primary_key: :code, inverse_of: :rates, optional: true
    belongs_to :factor_type_catalog, class_name: 'SatFactorType', foreign_key: :factor_type, primary_key: :code, inverse_of: :tax_rates, optional: true

  scope :active, -> { where(status: true) }
  scope :valid_on, ->(date = Date.current) {
    where('(valid_from IS NULL OR valid_from <= :date) AND (valid_to IS NULL OR valid_to >= :date)', date: date)
  }
  scope :current, -> { active.valid_on }

  validates :catalog_key, :description, presence: true
  validates :catalog_key, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :tax_code, :factor_type, :tax_type, presence: true
  validate :rate_range
  validate :valid_date_range

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) && (valid_to.nil? || valid_to >= date)
  end

  private

  def valid_date_range
    errors.add(:valid_to, 'must be on or after valid_from') if valid_from && valid_to && valid_to < valid_from
  end
  
  def rate_range
    errors.add(:maximum_rate, 'must be greater than or equal to minimum_rate') if minimum_rate && maximum_rate && maximum_rate < minimum_rate
  end
end
