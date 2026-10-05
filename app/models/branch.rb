# frozen_string_literal: true

class Branch < ApplicationRecord
  belongs_to :organization, optional: true
  has_one :address, as: :addressable, dependent: :destroy
  accepts_nested_attributes_for :address

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles
  has_many :terminals, dependent: :restrict_with_exception

  scope :not_deleted, -> { where(deleted_at: nil) }

  validates :name,
            presence: true,
            length: { in: 2..100 },
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false,
              conditions: -> { where(deleted_at: nil) }
            },
            on: %i[create update]
  validates :phone,
            format: { with: /\A[0-9+\-\s()]{7,20}\z/ },
            length: { in: 7..20 },
            allow_blank: true,
            on: %i[create update]
  validates :status, inclusion: { in: [true, false] }, on: %i[create update]
end
