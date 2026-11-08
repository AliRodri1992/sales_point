# frozen_string_literal: true

class InventoryLot < ApplicationRecord
  include RestrictsClosedBranchMutations
  has_paper_trail
  belongs_to :organization
  belongs_to :inventory
  belongs_to :goods_receipt_item, optional: true
  has_many :inventory_serials, dependent: :restrict_with_exception
  has_many :inventory_movements, dependent: :restrict_with_exception

  enum :status, { available: 'available', quarantined: 'quarantined',
                  expired: 'expired', depleted: 'depleted' }, validate: true

  validates :code, presence: true, uniqueness: { scope: :inventory_id }
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :consistent_organization
  validate :receipt_matches_inventory

  scope :fefo, -> { available.where('quantity > 0').order(Arel.sql('expires_on ASC NULLS LAST'), :id) }
  scope :saleable, -> { fefo.where('expires_on IS NULL OR expires_on >= ?', Date.current) }

  private

  def receipt_matches_inventory
    return unless goods_receipt_item && inventory

    receipt = goods_receipt_item.goods_receipt
    product_id = goods_receipt_item.purchase_order_item&.product_id
    valid = receipt && receipt.branch_id == inventory.branch_id &&
            receipt.organization_id == inventory.organization_id &&
            product_id == inventory.product_id
    errors.add(:goods_receipt_item, :invalid) unless valid
  end

  def consistent_organization
    errors.add(:inventory, :invalid) if inventory && inventory.organization_id != organization_id
  end
end
