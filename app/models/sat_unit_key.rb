class SatUnitKey < ApplicationRecord
  CODE_FORMAT = /\A[A-Z0-9]{1,5}\z/

  scope :not_deleted, -> { where(deleted_at: nil) }

  scope :active, -> { not_deleted }

  scope :valid_on, lambda { |date = Date.current|
    where(
      '(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)',
      date, date
    )
  }

  scope :current, -> { active.valid_on(Date.current) }

  scope :ordered, -> { order(:code) }

  validates :code,
            presence: true,
            length: { maximum: 5 },
            format: { with: CODE_FORMAT },
            uniqueness: {
              case_sensitive: false,
              conditions: -> { where(deleted_at: nil) }
            }

  validates :description, presence: true

  validates :symbol, length: { maximum: 10 }, allow_blank: true

  validate :valid_date_range

  before_validation :normalize_fields

  def active?
    deleted_at.nil?
  end

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) &&
      (valid_to.nil? || valid_to >= date)
  end

  def to_label
    if symbol.present?
      "#{code} - #{description} (#{symbol})"
    else
      "#{code} - #{description}"
    end
  end

  def soft_delete!(user_id = nil)
    update(deleted_at: Time.current, deleted_by: user_id)
  end

  def self.for_code(code, date = Date.current)
    active.valid_on(date).find_by(code: code.to_s.upcase.strip)
  end

  private

  def normalize_fields
    self.code = code.to_s.strip.upcase
    self.description = description.to_s.strip
    self.symbol = symbol.to_s.strip.presence
  end

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    return unless valid_to < valid_from

    errors.add(:valid_to, 'must be greater than or equal to valid_from')
  end
end
