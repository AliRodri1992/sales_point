# frozen_string_literal: true

class Area < ApplicationRecord
  validates :name,
            presence: true,
            length: { maximum: 50 }

  validates :code,
            presence: true,
            uniqueness: true,
            length: { maximum: 20 },
            format: { with: /\A[a-z0-9_]+\z/ }

  enum :status,
       {
         active: 'active',
         inactive: 'inactive'
       },
       validate: true

  # New areas always default to "active" so the status field doesn't
  # need to be exposed on the create form.
  after_initialize :set_default_status, if: :new_record?

  scope :available, lambda {
    where(status: :active)
  }

  scope :not_deleted, lambda {
    where(deleted_at: nil)
  }

  private

  def set_default_status
    self.status ||= 'active'
  end
end
