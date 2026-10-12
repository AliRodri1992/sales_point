# frozen_string_literal: true

module Inventories
  class Transfer
    def self.call(from:, to:, quantity:, user: nil, reference: nil)
      raise ArgumentError, 'Cannot transfer across organizations' unless from.organization_id == to.organization_id
      raise ArgumentError, 'Product mismatch' unless from.product_id == to.product_id
      raise ArgumentError, 'Source and destination must differ' if from.id == to.id

      amount = BigDecimal(quantity.to_s)
      raise ArgumentError, 'Quantity must be positive' unless amount.positive?

      Inventory.transaction do
        inventories = Inventory.where(id: [from.id, to.id]).order(:id).lock.to_a.index_by(&:id)
        source = inventories.fetch(from.id)
        target = inventories.fetch(to.id)
        Inventories::ApplyMovement.call(inventory: source, quantity: -amount, kind: 'transfer_out',
                                        user:, reference:)
        Inventories::ApplyMovement.call(inventory: target, quantity: amount, kind: 'transfer_in',
                                        user:, reference:)
      end
    end
  end
end
