# frozen_string_literal: true

class InventorySerial < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :inventory_lot

  enum :status, { available: 'available', sold: 'sold', returned: 'returned',
                  quarantined: 'quarantined' }, validate: true

  validates :serial_number, presence: true, uniqueness: { scope: :organization_id }
  validate :consistent_organization

  private

  def consistent_organization
    errors.add(:inventory_lot, :invalid) if inventory_lot && inventory_lot.organization_id != organization_id
  end
end
