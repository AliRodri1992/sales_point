# frozen_string_literal: true

class Supplier < ApplicationRecord
  has_many :contacts, as: :contactable, dependent: :restrict_with_exception
  has_many :addresses, as: :addressable, dependent: :restrict_with_exception
  belongs_to :sat_fiscal_regime, optional: true

  validates :code,
            presence: true,
            uniqueness: { conditions: -> { where(deleted_at: nil) } },
            length: { maximum: 30 },
            format: { with: /\A[A-Za-z0-9\-_]+\z/, message: :invalid_format }

  validates :name, presence: true, length: { maximum: 150 }

  validates :email,
            length: { maximum: 150 },
            format: { with: URI::MailTo::EMAIL_REGEXP },
            allow_blank: true

  validates :phone, length: { maximum: 30 }, allow_blank: true

  validates :rfc,
            length: { in: 12..13 },
            uniqueness: { conditions: -> { where(deleted_at: nil) } },
            format: { with: /\A[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}\z/i, message: :invalid_format },
            allow_blank: true

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

  def normalize_fields
    normalize_text_field(:code, &:strip)
    normalize_text_field(:name, &:strip)
    normalize_email
    normalize_text_field(:phone, &:strip)
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

  def normalize_email
    email_value = email.to_s.strip.downcase
    self.email = email_value.presence
  end

  def normalize_rfc
    rfc_value = rfc.to_s.strip.upcase
    self.rfc = rfc_value.presence
  end
end
