# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatCustomsPedimentNumber < ApplicationRecord
  include SatCatalogValidity

  belongs_to :customs_office,
             class_name: 'SatCustomsOffice',
             foreign_key: :customs_office_code,
             primary_key: :code,
             optional: true,
             inverse_of: :pediment_numbers

  belongs_to :patent,
             class_name: 'SatCustomsPatent',
             foreign_key: :patent_code,
             primary_key: :code,
             optional: true,
             inverse_of: :pediment_numbers

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :fiscal_year,
            numericality: { only_integer: true, greater_than_or_equal_to: 2000, less_than_or_equal_to: 2100 },
            allow_nil: true
end
