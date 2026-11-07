# frozen_string_literal: true

class Branch < ApplicationRecord
  include HasPolymorphicNotes
  has_many :phones, as: :phoneable, dependent: :restrict_with_exception
  accepts_nested_attributes_for :phones,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs['number'].blank? && attrs['id'].blank? }
  belongs_to :organization, optional: true
  has_one :address, as: :addressable, dependent: :destroy
  accepts_nested_attributes_for :address

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles
  has_many :inventories, dependent: :restrict_with_exception
  has_many :purchase_requests, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception
  has_many :goods_receipts, dependent: :restrict_with_exception
  has_many :terminals, dependent: :restrict_with_exception

  attribute :status, :boolean, default: true
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
            length: { in: 2..100 },
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false,
              conditions: -> { where(deleted_at: nil) }
            },
            on: %i[create update]
  validates :status, inclusion: { in: [true, false] }, on: %i[create update]

  validates :name,
            presence: true,
            length: { in: 2..100 },
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

  def preserve_operational_history
    protected_records = [inventories, purchase_requests, purchase_orders, goods_receipts, terminals]
    return unless protected_records.any? { |records| records.with_deleted.exists? }

    errors.add(:base, I18n.t('admin.catalog_design.branch_has_history'))
  end
end
