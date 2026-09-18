# frozen_string_literal: true

class SatBank < ApplicationRecord
  CODE_FORMAT = /\A\d{3}\z/

  scope :active, -> { where(status: true) }

  scope :valid_on, lambda { |date = Date.current|
    where(
      '(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)',
      date, date
    )
  }

  scope :current, -> { active.valid_on(Date.current) }

  scope :search, lambda { |term|
    term.present? ? where('name ILIKE ?', "%#{term}%") : all
  }

  validates :code,
            presence: true,
            format: { with: CODE_FORMAT },
            uniqueness: { conditions: -> { where(deleted_at: nil) } }

  validates :name, presence: true

  validates :status, inclusion: { in: [true, false] }

  validate :valid_date_range

  before_validation :normalize_fields

  def active?
    status && deleted_at.nil?
  end

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) &&
      (valid_to.nil? || valid_to >= date)
  end

  def display_name
    "#{code} - #{name}"
  end

  def self.for_cfdi(code, date = Date.current)
    active.valid_on(date).find_by(code: normalize_code(code))
  end

  def self.exists_for_cfdi?(code, date = Date.current)
    active.valid_on(date).exists?(code: normalize_code(code))
  end

  def self.normalize_code(value)
    value.to_s.gsub(/\D/, '').rjust(3, '0')
  end

  private

  def normalize_fields
    normalized_code = code.to_s.strip
    self.code = if normalized_code.length == 1 && normalized_code.match?(/\A\d\z/)
                  normalized_code.rjust(3, '0')
                else
                  normalized_code.presence
                end
    self.name = name.to_s.strip.presence
  end

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    errors.add(:valid_to, 'must be greater than or equal to valid_from') if valid_to < valid_from
  end
end
