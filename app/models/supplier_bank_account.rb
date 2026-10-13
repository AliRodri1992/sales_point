# frozen_string_literal: true

class SupplierBankAccount < ApplicationRecord
  belongs_to :organization
  belongs_to :supplier
  belongs_to :sat_bank, foreign_key: :sat_bank_code, primary_key: :code, optional: true
  has_many :supplier_payments, dependent: :restrict_with_exception

  encrypts :account_number, :clabe
  validates :holder_name, presence: true, length: { maximum: 180 }
  validates :bank_name, presence: true, unless: -> { sat_bank_code.present? }
  validates :account_number, presence: true, unless: -> { clabe.present? }
  validates :currency_code, presence: true, length: { is: 3 }
  validate :same_organization
  validate :valid_clabe
  before_validation :normalize_bank_values

  scope :active, -> { where(deleted_at: nil) }

  def masked_number
    last_four.present? ? "•••• #{last_four}" : '••••'
  end

  def reveal!(actor:)
    raise Pundit::NotAuthorizedError unless actor&.admin? || actor&.permission?('accounts_payable.banks.reveal')

    FinancialAuditEvent.record!(organization:, actor:, event: 'bank_account.revealed', subject: self)
    { account_number: account_number, clabe: clabe }
  end

  private

  def same_organization
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
  end

  def normalize_bank_values
    self.clabe = clabe.to_s.gsub(/\s/, '').presence
    self.account_number = account_number.to_s.gsub(/\s/, '').presence
    self.last_four = (clabe.presence || account_number).to_s.last(4).presence
    self.currency_code = currency_code.to_s.upcase
  end

  def valid_clabe
    return if clabe.blank?

    unless clabe.match?(/\A\d{18}\z/)
      errors.add(:clabe, :invalid)
      return
    end
    weights = [3, 7, 1]
    sum = clabe[0, 17].chars.each_with_index.sum { |digit, index| (digit.to_i * weights[index % 3]) % 10 }
    errors.add(:clabe, :invalid) unless (10 - (sum % 10)) % 10 == clabe[-1].to_i
  end
end

