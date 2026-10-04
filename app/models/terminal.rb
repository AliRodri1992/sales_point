# frozen_string_literal: true

class Terminal < ApplicationRecord
  belongs_to :branch

  enum :status, {
    active: 'active',
    inactive: 'inactive'
  }

  validates :name, presence: true, length: { in: 2..80 }
  validates :code,
            presence: true,
            length: { in: 2..40 },
            format: { with: /\A[A-Z0-9_-]+\z/ },
            uniqueness: {
              scope: :branch_id,
              conditions: -> { where(deleted_at: nil) }
            }
  validates :status,
            presence: true,
            inclusion: { in: statuses.keys }

  scope :active_records, -> { where(deleted_at: nil, status: :active) }
end
