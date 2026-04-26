class SatTax < ApplicationRecord
  TAX_TYPES = %w[transfer withheld].freeze
  FACTOR_TYPES = %w[rate quota exempt].freeze
  APPLIES_TO = %w[product service both].freeze

  validates :code, uniqueness: { case_sensitive: false, conditions: -> { where(deleted_at: nil) } }
  validates :name, presence: true

  validates :tax_type, inclusion: { in: TAX_TYPES }
  validates :factor_type, inclusion: { in: FACTOR_TYPES }

  validates :applies_to, inclusion: { in: APPLIES_TO }, allow_nil: true

  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :valid_date_range
  validate :tax_logic_consistency

  before_validation :normalize_fields

  scope :not_deleted, -> { where(deleted_at: nil) }

  scope :active, -> { not_deleted.where(status: true) }

  scope :by_type, ->(type) { where(tax_type: type) }

  scope :ordered, -> { order(priority: :asc, code: :asc) }

  scope :valid_on, lambda { |date|
    where(
      '(valid_from IS NULL OR valid_from <= :date) AND (valid_to IS NULL OR valid_to >= :date)',
      date: date
    )
  }

  scope :for_products, -> { where(applies_to: %w[product both]) }
  scope :for_services, -> { where(applies_to: %w[service both]) }

  def transfer?
    tax_type == 'transfer'
  end

  def withheld?
    tax_type == 'withheld'
  end

  def rate?
    factor_type == 'rate'
  end

  def quota?
    factor_type == 'quota'
  end

  def exempt?
    factor_type == 'exempt'
  end

  def active?
    status && deleted_at.nil?
  end

  def valid_for_date?(date = Date.current)
    (valid_from.nil? || valid_from <= date) &&
      (valid_to.nil? || valid_to >= date)
  end

  def sat_code
    code.rjust(3, '0')
  end

  def normalize_fields
    self.code = code.to_s.strip.upcase
    self.name = name.to_s.strip
    self.applies_to = applies_to&.strip&.downcase
  end

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    errors.add(:valid_to, 'cannot be earlier than valid_from') if valid_to < valid_from
  end

  def tax_logic_consistency
    errors.add(:valid_to, 'cannot be earlier than valid_from') if transfer? && !is_transferrable

    errors.add(:is_retainable, 'must be TRUE for withheld taxes') if withheld? && !is_retainable
  end
end
