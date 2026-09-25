# frozen_string_literal: true

class Category < ApplicationRecord
  validates :name,
            presence: true,
            length: { maximum: 50 }

  validates :code,
            presence: true,
            uniqueness: true,
            length: { maximum: 20 },
            format: { with: /\A[a-z0-9_]+\z/ }

  validates :description,
            length: { maximum: 500 },
            allow_blank: true

  enum :status,
       {
         active: 'active',
         inactive: 'inactive'
       },
       validate: true,
       default: :active

  scope :available, lambda {
    where(status: :active)
  }

  scope :not_deleted, lambda {
    where(deleted_at: nil)
  }
end
