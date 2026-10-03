# frozen_string_literal: true

class OrganizationSetting < ApplicationRecord
  belongs_to :organization

  attribute :payment_method, :string

  enum :payment_method, {
    cash: 'cash',
    card: 'card',
    qr: 'qr'
  }

  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :timezone, :payment_method, presence: true
  validates :organization_id,
            uniqueness: { conditions: -> { where(deleted_at: nil) } }
end
