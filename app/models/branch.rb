# frozen_string_literal: true

class Branch < ApplicationRecord
  include HasPolymorphicNotes

  # Only the initial placeholder branch created during account registration can
  # be saved before the business has completed its address setup.
  include BranchLifecycle
  attr_accessor :registration_bootstrap

  has_many :phones, as: :phoneable, dependent: :restrict_with_exception
  accepts_nested_attributes_for :phones,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs['number'].blank? && attrs['id'].blank? }
  belongs_to :organization, optional: true
  validates :organization, presence: true, unless: :registration_bootstrap
  has_one :address, as: :addressable, dependent: :destroy
  accepts_nested_attributes_for :address

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles
  has_many :inventories, dependent: :restrict_with_exception
  has_many :purchase_requests, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception
  has_many :goods_receipts, dependent: :restrict_with_exception
  has_many :terminals, dependent: :restrict_with_exception

  attribute :status, :boolean, default: false
  before_validation :assign_branch_code
  normalizes :code, with: ->(value) { value.strip.upcase.presence }
  normalizes :contact_email, with: ->(value) { value.strip.downcase.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }
  validates :code, length: { maximum: 30 }, format: { with: /\A[A-Z0-9_-]+\z/ },
                   uniqueness: { scope: :organization_id, case_sensitive: false,
                                 conditions: -> { where(deleted_at: nil) } }, allow_nil: true
  validates :contact_email, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :notes, length: { maximum: 2000 }

  normalizes :name, with: ->(value) { value.strip }
  validate :preserve_operational_history, if: -> { will_save_change_to_deleted_at? && deleted_at.present? }

  scope :not_deleted, -> { where(deleted_at: nil) }

  validates :name,
            presence: true,
            length: { in: 3..150 },
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false,
              conditions: -> { where(deleted_at: nil) }
            },
            on: %i[create update]
  validates :status, inclusion: { in: [true, false] }, on: %i[create update]
  validates :address, presence: true, on: :create, unless: :registration_bootstrap
  validate :protect_branch_deactivation, if: :deactivating?

  validates :name,
            presence: true,
            length: { in: 3..150 },
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false,
              conditions: -> { where(deleted_at: nil) }
            },
            on: :onboardingstep2

  def self.team_assignments(organization)
    people = OrganizationMembership.accessible.where(organization:).select(:user_id)
    UserRole.active.joins(:user).merge(User.active).where(user_id: people)
  end

  private

  def assign_branch_code
    self.code = "BR-#{SecureRandom.hex(6).upcase}" if code.blank?
  end

  def deactivating?
    persisted? && will_save_change_to_status? && !status && deleted_at.nil? &&
      !lifecycle_transition_authorized
  end

  def protect_branch_deactivation
    errors.add(:status, I18n.t('admin.branch_workspace.active_team_block')) if active_team_assigned?
    errors.add(:status, I18n.t('admin.branch_workspace.active_operations_block')) if active_branch_operations?
    errors.add(:status, I18n.t('admin.branch_workspace.last_active_block')) if last_active_branch?
  end

  def active_team_assigned?
    user_roles.active.exists?
  end

  def last_active_branch?
    organization && organization.branches.not_deleted.where(operational_status: 'active').where.not(id: id).none?
  end

  def active_branch_operations?
    inventories.where('stock > 0').exists? ||
      terminals.active_records.exists? ||
      purchase_requests.exists?(status: %w[draft submitted]) ||
      purchase_orders.exists?(status: %w[draft pending_approval approved ordered partially_received])
  end

  def preserve_operational_history
    errors.add(:base, I18n.t('admin.branch_workspace.delete_team_block')) if user_roles.active.exists?
    protected_records = [inventories, purchase_requests, purchase_orders, goods_receipts, terminals]
    return unless protected_records.any? { |records| records.with_deleted.exists? }

    errors.add(:base, I18n.t('admin.catalog_design.branch_has_history'))
  end
end
