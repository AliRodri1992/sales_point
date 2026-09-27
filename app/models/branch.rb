# frozen_string_literal: true

class Branch < ApplicationRecord
  has_one :address, as: :addressable, dependent: :destroy
  accepts_nested_attributes_for :address

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles

  scope :not_deleted, -> { where(deleted_at: nil) }

  validates :name,
            presence: true,
            length: { in: 2..100 }

  validates :phone,
            format: { with: /\A[0-9+\-\s()]{7,20}\z/ },
            length: { in: 7..20 },
            allow_blank: true

  validates :status,
            inclusion: { in: [true, false] }
end
