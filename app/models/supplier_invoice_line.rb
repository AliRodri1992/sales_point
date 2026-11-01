# frozen_string_literal: true

class SupplierInvoiceLine < ApplicationRecord
  belongs_to :supplier_invoice
  validate :invoice_must_be_draft
  before_destroy :invoice_must_be_draft_for_destroy

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, :amount, numericality: { greater_than_or_equal_to: 0 }

  private

  def invoice_must_be_draft
    errors.add(:base, 'Invoice is not editable') unless supplier_invoice&.draft?
  end

  def invoice_must_be_draft_for_destroy
    return if supplier_invoice&.draft?

    errors.add(:base, 'Invoice is not editable')
    throw(:abort)
  end
end
