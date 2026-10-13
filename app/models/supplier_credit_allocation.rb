# frozen_string_literal: true

class SupplierCreditAllocation < ApplicationRecord
  belongs_to :organization
  belongs_to :supplier_credit_note
  belongs_to :account_payable
  validates :amount, numericality: { greater_than: 0 }
  validates :account_payable_id, uniqueness: { scope: :supplier_credit_note_id }
  validate :matching_organization

  private

  def matching_organization
    return unless supplier_credit_note && account_payable

    ids = [supplier_credit_note.organization_id, account_payable.organization_id, organization_id]
    suppliers = [supplier_credit_note.supplier_id, account_payable.supplier_id]
    errors.add(:account_payable, :invalid) unless ids.uniq.one? && suppliers.uniq.one?
  end
end
