# frozen_string_literal: true

class SupplierPaymentAllocation < ApplicationRecord
  belongs_to :organization
  belongs_to :supplier_payment
  belongs_to :account_payable
  validates :amount, numericality: { greater_than: 0 }
  validates :account_payable_id, uniqueness: { scope: :supplier_payment_id }
  validate :matching_organization

  private

  def matching_organization
    return unless supplier_payment && account_payable

    ids = [supplier_payment.organization_id, account_payable.organization_id, organization_id]
    suppliers = [supplier_payment.supplier_id, account_payable.supplier_id]
    errors.add(:account_payable, :invalid) unless ids.uniq.one? && suppliers.uniq.one?
  end
end

