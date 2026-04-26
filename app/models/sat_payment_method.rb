class SatPaymentMethod < ApplicationRecord
  CODE_FORMAT = /\A\d{2}\z/

  scope :active, -> { where(status: true, deleted_at: nil) }

  scope :valid_on, lambda { |date = Time.current|
    where(
      '(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)',
      date, date
    )
  }

  scope :current, -> { active.valid_on(Time.current) }

  scope :search, lambda { |term|
    term.present? ? where('description ILIKE ?', "%#{term}%") : all
  }

  validates :code,
            presence: true,
            format: { with: CODE_FORMAT },
            uniqueness: { conditions: -> { where(deleted_at: nil) } }

  validates :description, presence: true

  validates :status, inclusion: { in: [true, false] }

  validate :valid_date_range

  before_validation :normalize_fields

  def active?
    status && !deleted?
  end

  def valid_for_date?(date = Time.current)
    (valid_from.nil? || valid_from <= date) &&
      (valid_to.nil? || valid_to >= date)
  end

  def display_name
    "#{code} - #{description}"
  end

  def self.for_cfdi(code, date = Time.current)
    active.valid_on(date).find_by(code: normalize_code(code))
  end

  def self.exists_for_cfdi?(code, date = Time.current)
    active.valid_on(date).exists?(code: normalize_code(code))
  end

  def self.normalize_code(value)
    value.to_s.gsub(/\D/, '').rjust(2, '0')
  end

  private

  def normalize_fields
    self.code = self.class.normalize_code(code)
    self.description = description.to_s.strip.presence
  end

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    return unless valid_to < valid_from

    errors.add(:valid_to, 'must be greater than or equal to valid_from')
  end
end
