class SystemRole < ApplicationRecord
  enum :role_type, {
    system: 'system',
    branch: 'branch'
  }

  enum :status, {
    active: 'active',
    inactive: 'inactive',
    deprecated: 'deprecated'
  }

  validates :name, presence: true, length: { maximum: 50 }

  validates :role_type, presence: true

  validates :status, presence: true

  validates :name, uniqueness: { scope: :role_type }

  scope :system_roles, -> { where(role_type: 'system') }
  scope :branch_roles, -> { where(role_type: 'branch') }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { where(deleted_at: nil).where.not(status: 'deprecated') }

  private

  def active?
    status == 'active'
  end

  def inactive?
    status == 'inactive'
  end

  def deprecated?
    status == 'deprecated'
  end
end
