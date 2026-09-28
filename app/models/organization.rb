# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_exception
  has_one :current_subscription,
          -> { current },
          class_name: 'Subscription',
          inverse_of: :organization

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :active, -> { not_deleted.where(status: 'active') }

  validates :name, presence: true, length: { in: 2..150 }
  validates :code,
            presence: true,
            uniqueness: { conditions: -> { where(deleted_at: nil) } },
            format: { with: /\A[a-zA-Z0-9_-]+\z/ },
            length: { in: 2..50 }
  validates :legal_name, length: { maximum: 200 }, allow_blank: true
  validates :tax_id, length: { in: 12..13 }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone,
            format: { with: /\A[0-9+\-\s()]{7,30}\z/ },
            allow_blank: true
  validates :status, inclusion: { in: %w[active inactive] }
end
