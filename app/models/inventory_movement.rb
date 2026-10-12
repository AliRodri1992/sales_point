# frozen_string_literal: true

class InventoryMovement < ApplicationRecord
  belongs_to :organization
  belongs_to :inventory
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :inventory_lot, optional: true
  belongs_to :user, optional: true

  KINDS = %w[receipt sale adjustment transfer_in transfer_out return].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :quantity, numericality: { other_than: 0 }
  validates :stock_before, :stock_after, numericality: { greater_than_or_equal_to: 0 }
  validate :same_organization

  before_update :prevent_mutations
  before_destroy :prevent_mutations

  private

  def same_organization
    errors.add(:inventory, :invalid) if inventory && inventory.organization_id != organization_id
  end

  def prevent_mutations
    errors.add(:base, :readonly)
    throw :abort
  end
end
