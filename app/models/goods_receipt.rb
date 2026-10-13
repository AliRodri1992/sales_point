# frozen_string_literal: true

class GoodsReceipt < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  belongs_to :branch
  belongs_to :purchase_order
  belongs_to :received_by, class_name: 'User'
  has_many :goods_receipt_items, dependent: :restrict_with_exception
  has_many :purchase_returns, dependent: :restrict_with_exception

  enum :status, { posted: 'posted', reversed: 'reversed' }, validate: true
  validates :idempotency_key, presence: true, uniqueness: { scope: :organization_id }
  validates :received_at, presence: true
  validates :actual_freight_amount, :actual_insurance_amount, :extra_expenses_amount,
            :additional_discount_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :consistent_organization

  private

  def consistent_organization
    validate_order_organization
    validate_branch_organization
    validate_order_branch
  end

  def validate_order_organization
    errors.add(:purchase_order, :invalid) if purchase_order && purchase_order.organization_id != organization_id
  end

  def validate_branch_organization
    errors.add(:branch, :invalid) if branch && branch.organization_id != organization_id
  end

  def validate_order_branch
    return unless purchase_order && branch

    errors.add(:branch, :invalid) unless purchase_order.branch_id == branch.id
  end
end
