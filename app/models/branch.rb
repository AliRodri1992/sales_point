# frozen_string_literal: true

class Branch < ApplicationRecord
  has_many :phones, as: :phoneable, dependent: :restrict_with_exception
  accepts_nested_attributes_for :phones,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs['number'].blank? && attrs['id'].blank? }
  belongs_to :organization, optional: true
  has_one :address, as: :addressable, dependent: :destroy
  accepts_nested_attributes_for :address

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles
  has_many :inventories, dependent: :restrict_with_exception
  has_many :purchase_requests, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception
  has_many :goods_receipts, dependent: :restrict_with_exception
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
  validates :status, inclusion: { in: [true, false] }, on: %i[create update]

  validates :name,
            presence: true,
            length: { in: 2..100 },
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false,
              conditions: -> { where(deleted_at: nil) }
            },
            on: :onboardingstep2
end
