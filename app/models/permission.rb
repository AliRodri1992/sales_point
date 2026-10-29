# frozen_string_literal: true

class Permission < ApplicationRecord
  has_many :system_role_permissions, dependent: :destroy
  has_many :system_roles, through: :system_role_permissions

  enum :status, {
    active: 'active',
    inactive: 'inactive'
  }

  validates :code,
            presence: true,
            length: { maximum: 80 },
            format: { with: /\A[a-z0-9_.]+\z/ },
            uniqueness: true

  validates :name, presence: true, length: { maximum: 80 }
  validates :module_name, presence: true, length: { maximum: 50 }
  validates :status, presence: true

  scope :available, -> { where(status: 'active').order(:module_name, :name) }

  after_commit :provision_administrators, on: %i[create update], if: :requires_provisioning?

  private

  def requires_provisioning?
    active? && (saved_change_to_id? || saved_change_to_status?)
  end

  def provision_administrators
    AdministratorPermissionProvisioner.call_for_permission(permission: self)
  end
end
