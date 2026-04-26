class SatMonth < ApplicationRecord
  MONTH_CODES = %w[
    01 02 03 04 05 06
    07 08 09 10 11 12
  ].freeze

  scope :not_deleted, -> { where(deleted_at: nil) }

  scope :active, -> { not_deleted.where(status: true) }

  scope :ordered, -> { order(:month_number) }

  scope :valid_on, lambda { |date = Date.current|
    where(
      "(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)",
      date, date
    )
  }

  scope :current, -> { active.valid_on(Date.current).ordered }

  validates :code,
            presence: true,
            inclusion: { in: MONTH_CODES },
            uniqueness: {
              case_sensitive: false,
              conditions: -> { where(deleted_at: nil) }
            }

  validates :description, presence: true

  validates :month_number,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 12
            }

  validate :valid_date_range
  validate :code_matches_month_number

  before_validation :normalize_fields

  def active?
    status && deleted_at.nil?
  end

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) &&
      (valid_to.nil? || valid_to >= date)
  end

  def month_name
    Date::MONTHNAMES[month_number]
  end

  def to_label
    "#{code} - #{description.presence || month_name}"
  end

  def self.for_code(code, date = Date.current)
    active.valid_on(date).find_by(code: code)
  end

  private

  def normalize_fields
    return if code.blank?

    self.code = code.to_s.strip.rjust(2, '0')
    self.description = description.to_s.strip
  end

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    errors.add(:valid_to, 'must be greater than or equal to valid_from') if valid_to < valid_from
  end

  def code_matches_month_number
    return if code.blank? || month_number.blank?

    errors.add(:code, 'must match month_number') if code.to_i != month_number
  end
end
