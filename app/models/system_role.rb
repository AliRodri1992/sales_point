class SystemRole < ApplicationRecord
  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles

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

  validates :code,
            presence: true,
            length: { maximum: 50 },
            format: { with: /\A[a-z0-9_]+\z/ },
            uniqueness: true

  validates :role_type, presence: true

  validates :status, presence: true

  validates :name, uniqueness: { scope: :role_type }

  before_validation :generate_code

  scope :system_roles, -> { where(role_type: 'system') }
  scope :branch_roles, -> { where(role_type: 'branch') }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deprecated, -> { with_deleted.where(status: 'deprecated') }
  scope :available, -> { where(deleted_at: nil).where.not(status: 'deprecated') }

  private

  def generate_code
    self.code = name.to_s.parameterize(separator: '_') if code.blank? && name.present?
  end
end
