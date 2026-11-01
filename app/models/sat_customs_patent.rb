# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatCustomsPatent < ApplicationRecord
  include SatCatalogValidity

  has_many :pediment_numbers,
           class_name: 'SatCustomsPedimentNumber',
           foreign_key: :patent_code,
           primary_key: :code,
           inverse_of: :patent,
           dependent: :restrict_with_exception

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, format: { with: /\A\d{4}\z/ }
end
