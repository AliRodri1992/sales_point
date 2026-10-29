class SystemRole < ApplicationRecord
  ADMINISTRATIVE_CODES = %w[administrator super_admin].freeze

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles
  has_many :system_role_permissions, dependent: :destroy
  has_many :permissions, through: :system_role_permissions

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
  after_create_commit :provision_administrative_permissions, if: :administrative_role_ready?
  after_update_commit :provision_administrative_permissions, if: :administrative_role_activated?

  scope :system_roles, -> { where(role_type: 'system') }
  scope :branch_roles, -> { where(role_type: 'branch') }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deprecated, -> { with_deleted.where(status: 'deprecated') }
  scope :available, -> { where(deleted_at: nil).where.not(status: 'deprecated') }

  def protected_permissions?
    ADMINISTRATIVE_CODES.include?(code)
  end

  private

  def administrative_role_ready?
    protected_permissions? && system? && active? && deleted_at.nil?
  end

  def administrative_role_activated?
    administrative_role_ready? &&
      (saved_change_to_code? || saved_change_to_status? || saved_change_to_deleted_at?)
  end

  def provision_administrative_permissions
    AdministratorPermissionProvisioner.call(role: self)
  end

  def generate_code
    self.code = name.to_s.parameterize(separator: '_') if code.blank? && name.present?
  end
end
