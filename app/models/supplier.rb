# frozen_string_literal: true

class Supplier < ApplicationRecord
  include SupplierDocumentTypes
  include SupplierLifecycle
  include SupplierFiscalRules

  has_paper_trail

  belongs_to :organization
  has_many :supplier_products, dependent: :restrict_with_exception
  has_many :purchase_quotations, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception
  include SupplierFinancialAssociations

  has_many :products, through: :supplier_products

  belongs_to :currency
  has_many :contacts, as: :contactable, dependent: :restrict_with_exception
  accepts_nested_attributes_for :contacts, allow_destroy: true, reject_if: :all_blank
  has_many :addresses, as: :addressable, dependent: :restrict_with_exception
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :all_blank
  belongs_to :sat_fiscal_regime, optional: true
  belongs_to :responsible_user, class_name: 'User', optional: true
  has_many :supplier_schedules, dependent: :destroy
  has_many :supplier_events, dependent: :destroy
  has_many :supplier_schedule_exceptions, dependent: :destroy
  has_many_attached :documents
  has_many :supplier_documents, dependent: :restrict_with_exception
  validate :responsible_user_in_organization
  validate :documents_are_safe

  def tags_text = tags.join(', ')

  def tags_text=(value)
    self.tags = value.to_s.split(',').map(&:strip).compact_blank.uniq.first(20)
  end

  validates :code,
            presence: true,
            uniqueness: { scope: :organization_id, conditions: -> { where(deleted_at: nil) } },
            length: { maximum: 30 },
            format: { with: /\A[A-Za-z0-9\-_]+\z/, message: :invalid_format }

  validates :name, presence: true, length: { maximum: 150 }
  validates :legal_name, :trade_name, length: { maximum: 150 }, allow_blank: true
  validates :alias_name, length: { maximum: 100 }, allow_blank: true
  validates :classification, inclusion: { in: %w[manufacturer distributor wholesaler service other] }, allow_blank: true
  validates :person_type, presence: true, inclusion: { in: %w[individual company] }
  validates :credit_days, numericality: { only_integer: true, in: 0..365 }
  validates :credit_limit, :minimum_order_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percent, numericality: { in: 0..100 }

  validates :email,
            length: { maximum: 150 },
            format: { with: URI::MailTo::EMAIL_REGEXP },
            allow_blank: true

  validates :phone, length: { maximum: 30 }, allow_blank: true
  validate :phone_must_be_valid

  validates :notes, length: { maximum: 1000 }, allow_blank: true

  enum :status, { active: 'active', inactive: 'inactive' }, validate: true, default: :active

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { not_deleted.where(status: :active) }
  scope :search, lambda { |term|
    where('code ILIKE :q OR name ILIKE :q OR email ILIKE :q OR phone ILIKE :q OR rfc ILIKE :q', q: "%#{term}%")
  }
  scope :with_status, ->(status) { where(status: status) }
  scope :sorted, ->(column, direction) { order(column => direction) }

  before_validation :assign_generated_code, on: :create
  before_validation :normalize_fields

  private

  def assign_generated_code
    return if code.present? || organization.blank? || !organization.persisted?

    organization.with_lock do
      existing = organization.suppliers.where('code LIKE ?', 'PROV-%').pluck(:code)
      numbers = existing.filter_map do |value|
        digits = value.delete_prefix('PROV-')
        digits.to_i if digits.match?(/\\A[0-9]+\\z/)
      end
      last_number = numbers.max || 0

      self.code = format('PROV-%06d', last_number + 1)
    end
  end

  def responsible_user_in_organization
    return if responsible_user.blank?

    memberships = organization&.organization_memberships&.active
    errors.add(:responsible_user, :invalid) unless memberships&.exists?(user_id: responsible_user_id)
  end

  def normalize_fields
    normalize_text_field(:code, &:strip)
    normalize_text_field(:name, &:strip)
    %i[legal_name trade_name alias_name].each { |field| normalize_text_field(field, &:strip) }
    normalize_email
    normalize_phone
    normalize_rfc
    normalize_text_field(:notes, &:strip)
  end

  def normalize_text_field(field, &normalization)
    value = send(field)
    return if value.blank?

    value = value.strip if normalization
    send("#{field}=", value)
  end

  def normalize_email = (self.email = email.to_s.strip.downcase.presence)

  def normalize_phone
    return if phone.blank?

    parsed = Phonelib.parse(phone.to_s.strip, 'MX')
    self.phone = parsed.e164 if parsed.valid?
  end

  def phone_must_be_valid
    return if phone.blank?

    errors.add(:phone, :invalid) unless Phonelib.parse(phone, 'MX').valid?
  end

  def normalize_rfc
    rfc_value = rfc.to_s.strip.upcase
    self.rfc = rfc_value.presence
  end
end
