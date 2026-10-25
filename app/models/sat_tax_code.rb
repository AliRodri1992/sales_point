# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatTaxCode < ApplicationRecord
  include SatCatalogValidity

  has_many :rates,
           class_name: 'SatTaxRate',
           foreign_key: :tax_code,
           primary_key: :code,
           inverse_of: :tax_code_catalog,
           dependent: :restrict_with_exception

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, format: { with: /\A\d{3}\z/ }
end
