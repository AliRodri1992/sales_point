# frozen_string_literal: true

class SupplierBankAccount < ApplicationRecord
  ACCOUNT_TYPES = %w[checking savings payroll business other].freeze
  STATUSES = %w[active inactive blocked].freeze
  VERIFICATION_STATUSES = %w[pending verified rejected].freeze

  belongs_to :organization
  belongs_to :supplier
  belongs_to :sat_bank, foreign_key: :sat_bank_code, primary_key: :code,
                        optional: true, inverse_of: :supplier_bank_accounts
  has_many :supplier_payments, dependent: :restrict_with_exception

  # Paranoia is inherited from ApplicationRecord: deleted_at is a timestamp.
  encrypts :clabe
  validates :holder_name, presence: true, length: { maximum: 180 }
  validates :bank_name, presence: true, unless: -> { sat_bank_code.present? }
  validates :bank_name, length: { maximum: 120 }, allow_blank: true
  validates :clabe, presence: true
  validates :currency_code, presence: true, length: { is: 3 }
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }
  validates :blocked_reason, presence: true, if: -> { status == 'blocked' }
  validates :blocked_reason, length: { maximum: 500 }, allow_blank: true
  validate :same_organization
  validate :supplier_available_for_creation, on: :create
  validate :valid_clabe
  validate :consistent_bank_code
  validate :sat_bank_code_exists

  before_validation :normalize_bank_values
  before_validation :normalize_verification

  scope :active, -> { where(deleted_at: nil) }
  scope :eligible_for_online_payment, lambda {
    active.where(status: 'active', verification_status: 'verified').where.not(clabe: nil)
  }

  def masked_number
    last_four.present? ? "•••• #{last_four}" : '••••'
  end

  def reveal!(actor:)
    raise Pundit::NotAuthorizedError unless Pundit.policy(actor, self)&.reveal?

    FinancialAuditEvent.record!(organization:, actor:, event: 'bank_account.revealed', subject: self)
    { clabe: clabe }
  end

  private

  def supplier_available_for_creation
    errors.add(:supplier, :invalid) unless supplier&.active? && supplier.deleted_at.nil?
  end

  def same_organization
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
  end

  def normalize_bank_values
    normalize_sensitive_numbers
    normalize_display_fields
    derive_sat_bank_from_clabe
  end

  def normalize_sensitive_numbers
    self.clabe = compact_number(clabe)
  end

  def normalize_display_fields
    self.last_four = clabe.to_s.last(4).presence
    self.currency_code = currency_code.to_s.upcase
  end

  def derive_sat_bank_from_clabe
    return unless clabe&.match?(/\A\d{18}\z/) && sat_bank_code.blank?

    bank = SatBank.current.find_by(code: clabe.first(3))
    self.sat_bank_code = bank.code if bank
  end

  def normalize_verification
    self.primary = false if status.in?(%w[inactive blocked])
    self.blocked_reason = blocked_reason.to_s.strip.presence if status == 'blocked'
    self.blocked_reason = nil unless status == 'blocked'
    self.verified_at = nil unless verification_status == 'verified'
  end

  def compact_number(value) = value.to_s.delete(" \t\n").presence

  def valid_clabe
    return if clabe.blank?

    errors.add(:clabe, :invalid) unless valid_clabe_format? && valid_clabe_checksum?
  end

  def consistent_bank_code
    return if clabe.blank? || sat_bank_code.blank?

    errors.add(:sat_bank_code, :invalid) unless clabe.start_with?(sat_bank_code)
  end

  def sat_bank_code_exists
    return if sat_bank_code.blank? || SatBank.exists?(code: sat_bank_code)

    errors.add(:sat_bank_code, :invalid)
  end

  def valid_clabe_format?
    clabe.match?(/\A\d{18}\z/)
  end

  def valid_clabe_checksum?
    weights = [3, 7, 1]
    sum = clabe[0, 17].chars.each_with_index.sum { |digit, index| (digit.to_i * weights[index % 3]) % 10 }
    (10 - (sum % 10)) % 10 == clabe[-1].to_i
  end
end
