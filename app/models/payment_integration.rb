# frozen_string_literal: true

class PaymentIntegration < ApplicationRecord
  belongs_to :organization

  enum :provider, { card: 'card', qr: 'qr' }
  enum :status, { pending: 'pending', active: 'active', inactive: 'inactive' }

  validates :provider, presence: true
  validates :status, presence: true
  validates :organization_id, uniqueness: {
    scope: :provider,
    conditions: -> { where(deleted_at: nil) }
  }
end