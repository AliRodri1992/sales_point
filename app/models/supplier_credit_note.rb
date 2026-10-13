# frozen_string_literal: true

class SupplierCreditNote < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :supplier
  belongs_to :currency
  belongs_to :supplier_invoice, optional: true
  belongs_to :purchase_return, optional: true
  belongs_to :created_by, class_name: 'User'
  has_many :supplier_credit_allocations, dependent: :restrict_with_exception
  has_one_attached :xml_document
  enum :status, { draft: 'draft', posted: 'posted', cancelled: 'cancelled' }, validate: true
  validates :issued_on, presence: true
  validates :total, numericality: { greater_than: 0 }
  validates :uuid, uniqueness: { scope: :organization_id }, allow_blank: true
  validate :matching_organization
  before_validation { self.uuid = uuid.to_s.strip.upcase.presence }

  def available_amount
    total - supplier_credit_allocations.sum(:amount)
  end

  private

  def matching_organization
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
    if supplier_invoice && (supplier_invoice.supplier_id != supplier_id ||
                            supplier_invoice.organization_id != organization_id)
      errors.add(:supplier_invoice, :invalid)
    end
    if purchase_return && purchase_return.organization_id != organization_id
      errors.add(:purchase_return, :invalid)
    end
  end
end

