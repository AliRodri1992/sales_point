# frozen_string_literal: true

class InventoryLot < ApplicationRecord
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

  scope :fefo, -> { available.where('quantity > 0').order(Arel.sql('expires_on ASC NULLS LAST'), :id) }
  scope :saleable, -> { fefo.where('expires_on IS NULL OR expires_on >= ?', Date.current) }

  private

  def consistent_organization
    errors.add(:inventory, :invalid) if inventory && inventory.organization_id != organization_id
  end
end
