# frozen_string_literal: true

class Category < ApplicationRecord
  belongs_to :organization, optional: true
  has_many :products, dependent: :restrict_with_error
  has_many :promotion_conditions, dependent: :restrict_with_error

  validates :name,
            presence: true,
            length: { maximum: 50 }

  validates :code,
            presence: true,
            uniqueness: { scope: :organization_id, conditions: -> { where(deleted_at: nil) } },
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

  # Soft deletion must not obscure active commercial references.
  def in_use?
    products.exists? || promotion_conditions.exists?
  end

  scope :for_organization, ->(organization) { where(organization_id: organization&.id) }

  scope :available, lambda {
    where(status: :active)
  }

  scope :not_deleted, lambda {
    where(deleted_at: nil)
  }
end
