class SystemRole < ApplicationRecord
  ADMINISTRATIVE_CODES = %w[administrator super_admin].freeze
  STATUS_TRANSITIONS = {
    'active' => %w[inactive], 'inactive' => %w[active deprecated], 'deprecated' => %w[inactive]
  }.freeze

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles
  has_many :system_role_permissions, dependent: :destroy
  has_many :permissions, through: :system_role_permissions
  has_many :status_events, class_name: 'SystemRoleStatusEvent', dependent: :restrict_with_exception
  has_many :permission_audit_events, class_name: 'SystemRolePermissionAuditEvent',
                                     dependent: :restrict_with_exception

  enum :role_type, {
    system: 'system',
    branch: 'branch'
  }, validate: true

  enum :status, {
    active: 'active',
    inactive: 'inactive',
    deprecated: 'deprecated'
  }, validate: true, default: :inactive

  normalizes :name, with: ->(value) { value.strip.gsub(/[[:space:]]+/, ' ') }
  attr_accessor :permission_ids

  validates :name, presence: true, length: { maximum: 50 }

  validates :code,
            presence: true,
            length: { maximum: 50 },
            format: { with: /\A[a-z0-9_]+\z/ },
            uniqueness: true

  validates :role_type, presence: true

  validates :status, presence: true

  validates :name, uniqueness: { scope: :role_type, case_sensitive: false }

  before_validation :generate_code
  validate :reviewed_status_transition, if: :persisted?
  before_destroy { throw :abort }
  after_commit :provision_administrative_permissions,
               on: %i[create update], if: :administrative_role_activated?

  scope :system_roles, -> { where(role_type: 'system') }
  scope :branch_roles, -> { where(role_type: 'branch') }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deprecated, -> { with_deleted.where(status: 'deprecated') }
  scope :available, -> { where(deleted_at: nil).where.not(status: 'deprecated') }
  scope :selectable_for, lambda { |user|
    retained_ids = user&.persisted? ? user.user_roles.select(:system_role_id) : []
    available.where(status: 'active').or(available.where(id: retained_ids))
  }

  def protected_permissions?
    ADMINISTRATIVE_CODES.include?(code)
  end

  private

  def reviewed_status_transition
    return unless will_save_change_to_status? || will_save_change_to_deleted_at?

    status_error(:review_required) unless validation_context == :status_transition
    status_error(:protected_role) if ADMINISTRATIVE_CODES.include?(code_in_database) || protected_permissions?
    status_error(:invalid_transition) unless STATUS_TRANSITIONS.fetch(status_in_database, []).include?(status)
    status_error(:invalid_transition) unless deprecated? == deleted_at.present?
  end

  def status_error(key)
    errors.add(:base, I18n.t("admin.system_roles.lifecycle.errors.#{key}"))
  end

  def administrative_role_ready?
    protected_permissions? && system? && active? && deleted_at.nil?
  end

  def administrative_role_activated?
    administrative_role_ready? &&
      (saved_change_to_id? || saved_change_to_code? || saved_change_to_status? || saved_change_to_deleted_at?)
  end

  def provision_administrative_permissions
    AdministratorPermissionProvisioner.call(role: self)
  end

  def generate_code
    return if code.present? || name.blank?

    self.code = name.parameterize(separator: '_').presence || "role_#{SecureRandom.hex(6)}"
  end
end
