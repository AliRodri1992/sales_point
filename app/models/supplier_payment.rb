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
    if supplier_bank_account && (supplier_bank_account.organization_id != organization_id ||
                                 supplier_bank_account.supplier_id != supplier_id)
      errors.add(:supplier_bank_account, :invalid)
    end
    return unless supplier_bank_account

    errors.add(:supplier_bank_account, :invalid) unless supplier_bank_account.deleted_at.nil?
    errors.add(:supplier_bank_account, :invalid) if currency && supplier_bank_account.currency_code != currency.code
  end
end
