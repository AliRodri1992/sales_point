# frozen_string_literal: true

class SupplierBankAccount < ApplicationRecord
  belongs_to :organization
  belongs_to :supplier
  belongs_to :sat_bank, foreign_key: :sat_bank_code, primary_key: :code,
                        optional: true, inverse_of: :supplier_bank_accounts
  has_many :supplier_payments, dependent: :restrict_with_exception

  encrypts :account_number, :clabe
  validates :holder_name, presence: true, length: { maximum: 180 }
  validates :bank_name, presence: true, unless: -> { sat_bank_code.present? }
  validates :account_number, presence: true, unless: -> { clabe.present? }
  validates :currency_code, presence: true, length: { is: 3 }
  validate :valid_card_preview
  validate :same_organization
  validate :supplier_available_for_creation, on: :create
  validate :valid_clabe
  validate :valid_account_number
  validate :consistent_bank_code
  before_validation :normalize_bank_values
  before_validation :normalize_card_preview

  scope :active, -> { where(deleted_at: nil) }

  def masked_number
    last_four.present? ? "•••• #{last_four}" : '••••'
  end

  def card_display_number
    "•••• •••• •••• #{card_last_four.presence || last_four.presence || '••••'}"
  end

  def card_expiration_label
    return if card_expiration_month.blank? || card_expiration_year.blank?

    format('%<month>02d/%<year>02d', month: card_expiration_month, year: card_expiration_year % 100)
  end

  def reveal!(actor:)
    raise Pundit::NotAuthorizedError unless Pundit.policy(actor, self)&.reveal?

    FinancialAuditEvent.record!(organization:, actor:, event: 'bank_account.revealed', subject: self)
    { account_number: account_number, clabe: clabe }
  end

  private

  def valid_card_preview
    values = [card_last_four, card_expiration_month, card_expiration_year]
    return if values.all?(&:blank?)

    errors.add(:card_last_four, :invalid) unless card_last_four.to_s.match?(/\\A\\d{4}\\z/)
    errors.add(:card_expiration_month, :invalid) unless (1..12).cover?(card_expiration_month.to_i)
    errors.add(:card_expiration_year, :invalid) unless (2000..2100).cover?(card_expiration_year.to_i)
  end

  def supplier_available_for_creation
    errors.add(:supplier, :invalid) unless supplier&.active? && supplier.deleted_at.nil?
  end

  def same_organization
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
  end

  def normalize_bank_values
    self.clabe = compact_number(clabe)
    self.account_number = compact_number(account_number)
    self.last_four = (clabe.presence || account_number).to_s.last(4).presence
    self.currency_code = currency_code.to_s.upcase
  end

  def normalize_card_preview
    self.card_last_four = card_last_four.to_s.strip.presence
  end

  def compact_number(value)
    value.to_s.delete(" \t\n").presence
  end

  def valid_clabe
    return if clabe.blank?

    errors.add(:clabe, :invalid) unless valid_clabe_format? && valid_clabe_checksum?
  end

  def valid_account_number
    return if account_number.blank?

    errors.add(:account_number, :invalid) unless account_number.match?(/\A\d{4,20}\z/)
  end

  def consistent_bank_code
    return if clabe.blank? || sat_bank_code.blank?

    errors.add(:sat_bank_code, :invalid) unless clabe.start_with?(sat_bank_code)
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
