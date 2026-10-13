# frozen_string_literal: true

class AccountPayable < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :supplier
  belongs_to :supplier_invoice
  has_many :supplier_payment_allocations, dependent: :restrict_with_exception
  has_many :supplier_credit_allocations, dependent: :restrict_with_exception
  validates :amount, numericality: { greater_than: 0 }
  validates :due_on, presence: true
  validate :consistent_invoice

  scope :outstanding, -> { joins(:supplier_invoice).where(supplier_invoices: { status: 'posted' }) }

  def paid_amount
    supplier_payment_allocations.joins(:supplier_payment)
                                .where(supplier_payments: { status: 'posted' }).sum(:amount)
  end

  def credited_amount
    supplier_credit_allocations.joins(:supplier_credit_note)
                               .where(supplier_credit_notes: { status: 'posted' }).sum(:amount)
  end

  def balance
    return 0.to_d unless supplier_invoice.posted?

    amount - paid_amount - credited_amount
  end

  def overdue?
    balance.positive? && due_on < Date.current
  end

  def settled?
    balance.zero?
  end

  private

  def consistent_invoice
    return unless supplier_invoice

    return if supplier_invoice.organization_id == organization_id && supplier_invoice.supplier_id == supplier_id

    errors.add(:supplier_invoice, :invalid)
  end
end
