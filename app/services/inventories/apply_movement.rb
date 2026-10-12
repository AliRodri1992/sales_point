# frozen_string_literal: true

module Inventories
  class ApplyMovement
    def self.call(inventory:, quantity:, kind:, user: nil, reference: nil)
      inventory.with_lock do
        amount = BigDecimal(quantity.to_s)
        raise ArgumentError, 'Quantity must not be zero' if amount.zero?
        raise ArgumentError, 'Invalid movement kind' unless InventoryMovement::KINDS.include?(kind)

        before = inventory.stock
        after = before + amount
        raise ActiveRecord::RecordInvalid, inventory if after.negative?

        inventory.update!(stock: after)
        inventory.inventory_movements.create!(
          organization: inventory.organization, user:, kind:, reference:,
          quantity: amount, stock_before: before, stock_after: after
        )
      end
    end
  end
end
