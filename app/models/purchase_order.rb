# frozen_string_literal: true

class PurchaseOrder < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  belongs_to :branch
  belongs_to :supplier
  belongs_to :currency
  belongs_to :requested_by, class_name: 'User'
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :purchase_request, optional: true
  belongs_to :purchase_quotation, optional: true
  has_many :purchase_order_items, dependent: :restrict_with_exception
  has_many :purchase_approvals, dependent: :restrict_with_exception
  has_many :goods_receipts, dependent: :restrict_with_exception
  has_many :supplier_invoices, dependent: :restrict_with_exception

  accepts_nested_attributes_for :purchase_order_items, reject_if: :all_blank
  enum :status, { draft: 'draft', pending_approval: 'pending_approval',
                  approved: 'approved', ordered: 'ordered', partially_received: 'partially_received',
                  received: 'received', closed: 'closed', rejected: 'rejected',
                  cancelled: 'cancelled' }, validate: true

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :freight_amount, :insurance_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :exchange_rate, numericality: { greater_than: 0 }
  validate :consistent_organization
  before_validation :set_code, on: :create

  def goods_total
    purchase_order_items.sum(&:line_total)
  end

  def total
    goods_total + freight_amount + insurance_amount
  end

  def received_quantity_for(item)
    GoodsReceiptItem.joins(:goods_receipt).where(purchase_order_item: item)
                    .sum(:accepted_quantity)
  end

  def outstanding_quantity_for(item)
    item.quantity - received_quantity_for(item)
  end

  def receivable?
    ordered? || partially_received?
  end

  private

  def set_code
    self.code ||= "PO-#{SecureRandom.hex(5).upcase}"
  end

  def consistent_organization
    validate_purchase_branch
    validate_purchase_supplier
    validate_purchase_request
    validate_purchase_quotation
    validate_purchase_items
  end

  def validate_purchase_branch
    errors.add(:branch, :invalid) if branch && branch.organization_id != organization_id
  end

  def validate_purchase_supplier
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
  end

  def validate_purchase_request
    return unless purchase_request

    valid = purchase_request.organization_id == organization_id &&
            purchase_request.branch_id == branch_id && purchase_request.approved?
    errors.add(:purchase_request, :invalid) unless valid
  end

  def validate_purchase_quotation
    return unless purchase_quotation

    errors.add(:purchase_quotation, :invalid) unless quotation_matches_order?
  end

  def quotation_matches_order?
    purchase_quotation.organization_id == organization_id &&
      purchase_quotation.supplier_id == supplier_id &&
      quotation_active? && quotation_request_matches?
  end

  def quotation_active?
    purchase_quotation.accepted? &&
      (purchase_quotation.valid_until.nil? || purchase_quotation.valid_until >= Date.current)
  end

  def quotation_request_matches?
    purchase_quotation.purchase_request_id.nil? ||
      purchase_quotation.purchase_request_id == purchase_request_id
  end

  def validate_purchase_items
    purchase_order_items.each do |item|
      next unless item.product

      errors.add(:purchase_order_items, :invalid) unless item.product.organization_id == organization_id
    end
  end
end
