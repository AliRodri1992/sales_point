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
  encrypts :account_number, :clabe, :card_number
  validates :holder_name, presence: true, length: { maximum: 180 }
  validates :bank_name, presence: true, unless: -> { sat_bank_code.present? }
  validates :bank_name, length: { maximum: 120 }, allow_blank: true
  validates :account_number, presence: true, unless: -> { clabe.present? }
  validates :clabe, presence: true, unless: -> { account_number.present? }
  validates :currency_code, presence: true, length: { is: 3 }
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }
  validates :blocked_reason, presence: true, if: -> { status == 'blocked' }
  validates :blocked_reason, length: { maximum: 500 }, allow_blank: true
  validate :same_organization
  validate :supplier_available_for_creation, on: :create
  validate :valid_clabe
  validate :valid_account_number
  validate :valid_card_number
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

  def card_display_number
    "•••• •••• •••• #{card_last_four.presence || last_four.presence || '••••'}"
  end

  # The bank card layout is retained; bank-account expiry is no longer stored.
  def card_expiration_label = nil

  def reveal!(actor:)
    raise Pundit::NotAuthorizedError unless Pundit.policy(actor, self)&.reveal?

    FinancialAuditEvent.record!(organization:, actor:, event: 'bank_account.revealed', subject: self)
    { account_number: account_number, clabe: clabe }
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
    self.account_number = compact_number(account_number)
    self.card_number = compact_number(card_number)
  end

  def normalize_display_fields
    self.last_four = (clabe.presence || account_number).to_s.last(4).presence
    self.card_last_four = card_number.to_s.last(4).presence
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
    if verification_status == 'verified'
      self.verified_at ||= Time.current
    else
      self.verified_at = nil
    end
  end

  def compact_number(value) = value.to_s.delete(" \t\n").presence

  def valid_clabe
    return if clabe.blank?

    errors.add(:clabe, :invalid) unless valid_clabe_format? && valid_clabe_checksum?
  end

  def valid_account_number
    return if account_number.blank?

    errors.add(:account_number, :invalid) unless account_number.match?(/\A\d{4,20}\z/)
  end

  def valid_card_number
    return if card_number.blank?

    digits = card_number.chars.map(&:to_i)
    return if card_number.match?(/\A\d{12,19}\z/) && luhn_checksum_valid?(digits)

    errors.add(:card_number, :invalid)
  end

  def luhn_checksum_valid?(digits)
    digits.reverse.each_with_index.sum do |digit, index|
      value = index.odd? ? digit * 2 : digit
      value > 9 ? value - 9 : value
    end.modulo(10).zero?
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
