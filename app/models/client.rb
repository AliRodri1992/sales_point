# frozen_string_literal: true

class Client < ApplicationRecord
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

  validates :credit_limit, numericality: { greater_than_or_equal_to: 0 }
  validates :notes, length: { maximum: 1000 }, allow_blank: true

  enum :status, { active: 'active', inactive: 'inactive' }, validate: true, default: :active

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { not_deleted.where(status: :active) }

  before_validation :normalize_fields

  private

  def normalize_fields
    self.code = code.to_s.strip
    self.name = name.to_s.strip
    self.email = email.to_s.strip.downcase.presence
    self.phone = phone.to_s.strip.presence
    self.rfc = rfc.to_s.strip.upcase.presence
    self.postal_code = postal_code.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end
end
