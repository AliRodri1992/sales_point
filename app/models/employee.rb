# frozen_string_literal: true

class Employee < ApplicationRecord
  belongs_to :organization
  has_one :user, dependent: :nullify

  enum :status, { active: 'active', inactive: 'inactive', terminated: 'terminated' }

  validates :first_name, presence: true, length: { in: 2..80 }
  validates :last_name, presence: true, length: { in: 2..120 }
  validates :email, presence: true,
            uniqueness: { scope: :organization_id, case_sensitive: false,
                          conditions: -> { where(deleted_at: nil) } },
            'valid_email_2/email': true
  validates :status, presence: true
end