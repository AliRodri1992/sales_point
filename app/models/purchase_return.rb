# frozen_string_literal: true

class PurchaseReturn < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  belongs_to :goods_receipt
  belongs_to :requested_by, class_name: 'User'
  has_many :purchase_return_items, dependent: :restrict_with_exception

  accepts_nested_attributes_for :purchase_return_items, reject_if: :all_blank
  enum :status, { draft: 'draft', processed: 'processed', cancelled: 'cancelled' }, validate: true
  enum :reason, { damaged: 'damaged', wrong_product: 'wrong_product',
                  expired: 'expired', surplus: 'surplus' }, validate: true

  validate :consistent_organization

  private

  def consistent_organization
    return unless goods_receipt

    errors.add(:goods_receipt, :invalid) unless goods_receipt.organization_id == organization_id
  end
end
