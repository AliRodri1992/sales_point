# frozen_string_literal: true

module Inventories
  class FefoAllocator
    def self.call(inventory:, quantity:, user:, source: nil, reference: nil, kind: 'sale')
      amount = BigDecimal(quantity.to_s)
      raise ArgumentError, 'Quantity must be positive' unless amount.positive?

      inventory.with_lock do
        raise ArgumentError, 'Insufficient inventory' if inventory.stock < amount

        remaining = amount
        inventory.inventory_lots.saleable.lock.each do |lot|
          next if remaining.zero?

          taken = [remaining, lot.quantity].min
          consume_lot!(inventory:, lot:, quantity: taken, user:, source:, reference:, kind:)
          remaining -= taken
        end
        raise ArgumentError, 'No usable, non-expired stock for this quantity' if remaining.positive?
      end
    end

    def self.consume_lot!(inventory:, lot:, quantity:, user:, source:, reference:, kind:)
      lot.update!(quantity: lot.quantity - quantity)
      if inventory.product.tracking_mode == 'serial'
        serials = lot.inventory_serials.available.order(:id).limit(quantity.to_i).to_a
        raise ArgumentError, 'Not enough available serial numbers' unless serials.size == quantity.to_i

        serials.each { |serial| serial.update!(status: :sold) }
      end
      Inventories::ApplyMovement.call(
        inventory:, quantity: -quantity, kind:, user:, source:, reference:, inventory_lot: lot
      )
    end
  end
end
