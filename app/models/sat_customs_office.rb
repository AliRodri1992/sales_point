# frozen_string_literal: true

# Official SAT CFDI 4.0 catalog with historical Paranoia records.
class SatCustomsOffice < ApplicationRecord
  include SatCatalogValidity

  has_many :pediment_numbers,
           class_name: 'SatCustomsPedimentNumber',
           foreign_key: :customs_office_code,
           primary_key: :code,
           inverse_of: :customs_office,
           dependent: :restrict_with_exception

  validates :code, :description, presence: true
  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :status, inclusion: { in: [true, false] }
  validates :code, format: { with: /\A\d{1,3}\z/ }
end
