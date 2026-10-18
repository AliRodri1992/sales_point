# frozen_string_literal: true

class Supplier < ApplicationRecord
  ALLOWED_DOCUMENT_TYPES = %w[
    application/pdf image/png image/jpeg text/plain text/csv application/csv
    application/xml text/xml application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/msword application/vnd.ms-excel
  ].freeze
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
  has_many_attached :documents
  validate :responsible_user_in_organization
  validate :documents_are_safe
  validate :rfc_must_match_person_type_and_date

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

  validates :rfc,
            length: { in: 12..13 },
            uniqueness: { scope: :organization_id, conditions: -> { where(deleted_at: nil) } },
            format: { with: /\A[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}\z/i, message: :invalid_format },
            presence: true

  validates :postal_code,
            format: { with: /\A\d{5}\z/, message: :invalid_format },
            allow_blank: true

  validates :notes, length: { maximum: 1000 }, allow_blank: true

  enum :status, { active: 'active', inactive: 'inactive' }, validate: true, default: :active

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { not_deleted.where(status: :active) }
  scope :search, lambda { |term|
    where('code ILIKE :q OR name ILIKE :q OR email ILIKE :q OR phone ILIKE :q OR rfc ILIKE :q', q: "%#{term}%")
  }
  scope :with_status, ->(status) { where(status: status) }
  scope :sorted, ->(column, direction) { order(column => direction) }

  before_validation :normalize_fields

  private

  def rfc_must_match_person_type_and_date
    return if rfc.blank? || !rfc.match?(/\A[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}\z/)

    prefix_length = rfc.length == 13 ? 4 : 3
    errors.add(:rfc, :person_type_mismatch) if rfc_person_type_mismatch?(prefix_length)
    errors.add(:rfc, :invalid_date) unless rfc_date_valid?(prefix_length)
  end

  def rfc_person_type_mismatch?(prefix_length)
    (person_type == 'individual' && prefix_length != 4) ||
      (person_type == 'company' && prefix_length != 3)
  end

  def rfc_date_valid?(prefix_length)
    date_digits = rfc[prefix_length, 6]
    month = date_digits[2, 2].to_i
    day = date_digits[4, 2].to_i
    year = date_digits[0, 2].to_i

    [2000 + year, 1900 + year].any? { |full_year| Date.valid_date?(full_year, month, day) }
  end

  def responsible_user_in_organization
    return if responsible_user.blank?

    errors.add(:responsible_user, :invalid) unless organization&.users&.exists?(id: responsible_user_id)
  end

  def documents_are_safe
    documents.each do |document|
      next unless document.blob

      errors.add(:documents, :invalid) unless document.blob.content_type.in?(ALLOWED_DOCUMENT_TYPES)
      errors.add(:documents, :file_too_large) if document.blob.byte_size > 10.megabytes
    end
  end

  def normalize_fields
    normalize_text_field(:code, &:strip)
    normalize_text_field(:name, &:strip)
    %i[legal_name trade_name alias_name].each { |field| normalize_text_field(field, &:strip) }
    normalize_email
    normalize_phone
    normalize_rfc
    normalize_text_field(:postal_code, &:strip)
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
