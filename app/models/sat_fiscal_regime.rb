class SatFiscalRegime < ApplicationRecord
  PERSON_TYPES = %w[F M].freeze

  scope :active, -> { where(deleted_at: nil) }

  scope :for_person, ->(type) {
    PERSON_TYPES.include?(type) ? where(person_type: type) : none
  }

  scope :valid_on, lambda { |date = Date.current|
    where(
      "(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)",
      date, date
    )
  }

  scope :current, ->(date = Date.current) { active.valid_on(date) }

  validates :code, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :description, presence: true
  validates :person_type, inclusion: { in: PERSON_TYPES }

  validate :valid_date_range

  before_validation :normalize_fields

  def self.for_cfdi(code, date = Date.current)
    active.valid_on(date).find_by(code: code)
  end

  def self.exists_for_cfdi?(code, date = Date.current)
    active.valid_on(date).exists?(code: code)
  end

  def physical_person?
    person_type == 'F'
  end

  def moral_person?
    person_type == 'M'
  end

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) &&
      (valid_to.nil? || valid_to >= date)
  end

  private

  def normalize_fields
    self.code = code.to_s.strip
    self.description = description.to_s.strip
    self.person_type = person_type.to_s.strip.upcase.presence
  end

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    if valid_to < valid_from
      errors.add(:valid_to, 'must be greater than or equal to valid_from')
    end
  end
end
