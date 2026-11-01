# frozen_string_literal: true

module Inventories
  class Transfer
    def self.call(from:, to:, quantity:, user: nil, reference: nil)
      validate_transfer!(from:, to:, quantity:)
      amount = BigDecimal(quantity.to_s)

      Inventory.transaction do
        inventories = Inventory.where(id: [from.id, to.id]).order(:id).lock.index_by(&:id)
        move(inventories.fetch(from.id), -amount, 'transfer_out', user:, reference:)
        move(inventories.fetch(to.id), amount, 'transfer_in', user:, reference:)
      end
    end

    def self.validate_transfer!(from:, to:, quantity:)
      raise ArgumentError, 'Cannot transfer across organizations' unless from.organization_id == to.organization_id
      raise ArgumentError, 'Product mismatch' unless from.product_id == to.product_id
      raise ArgumentError, 'Source and destination must differ' if from.id == to.id
      raise ArgumentError, 'Quantity must be positive' unless BigDecimal(quantity.to_s).positive?
    end

    def self.move(inventory, quantity, kind, user:, reference:)
      Inventories::ApplyMovement.call(inventory:, quantity:, kind:, user:, reference:)
    end
  end
end
