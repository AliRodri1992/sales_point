class SatPaymentMethodType < ApplicationRecord
  CODES = %w[PUE PPD].freeze

  scope :active, -> { where(status: true) }

  scope :valid_on, ->(date = Date.current) {
    where(
      "(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)",
      date, date
    )
  }

  scope :current, -> { valid_on(Date.current).active }

  validates :code, presence: true, inclusion: { in: CODES }, uniqueness: { conditions: -> { where(deleted_at: nil) } }

  validates :description, presence: true

  validate :valid_date_range

  before_validation :normalize_fields

  def pue?
    code == 'PUE'
  end

  def ppd?
    code == 'PPD'
  end

  def active?
    status && deleted_at.nil?
  end

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) && (valid_to.nil? || valid_to >= date)
  end

  def self.for_cfdi(code, date = Date.current)
    active.valid_on(date).find_by(code: code)
  end

  def self.exists_for_cfdi?(code, date = Date.current)
    active.valid_on(date).exists?(code: code)
  end

  private

  def normalize_fields
    self.code = code.to_s.strip.upcase.presence
    self.description = description.to_s.strip.presence
  end

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    if valid_to < valid_from
      errors.add(:valid_to, 'must be greater than or equal to valid_from') if valid_to < valid_from
    end
  end
end
