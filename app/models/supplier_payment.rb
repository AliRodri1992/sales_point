# frozen_string_literal: true

class SupplierPayment < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :supplier
  belongs_to :currency
  belongs_to :supplier_bank_account, optional: true
  belongs_to :created_by, class_name: 'User'
  has_many :supplier_payment_allocations, dependent: :restrict_with_exception

  enum :status, { draft: 'draft', posted: 'posted', reversed: 'reversed' }, validate: true
  validates :paid_on, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validate :matching_organization

  def allocated_amount
    supplier_payment_allocations.sum(:amount)
  end

  private

  def matching_organization
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
    validate_bank_account if supplier_bank_account
  end

  def validate_bank_account
    allowed = SupplierBankAccount.active.where(
      id: supplier_bank_account_id, organization_id:, supplier_id:, currency_code: currency&.code
    ).exists?
    errors.add(:supplier_bank_account, :invalid) unless allowed
  end
end
