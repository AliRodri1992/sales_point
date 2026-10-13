# frozen_string_literal: true

module Inventories
  class FefoAllocator
    def self.call(inventory:, quantity:, user:, kind: 'sale', **options)
      new(inventory:, quantity:, user:, kind:, options:).call
    end

    def initialize(inventory:, quantity:, user:, kind:, options:)
      @inventory = inventory
      @quantity = BigDecimal(quantity.to_s)
      @user = user
      @kind = kind
      @options = options
    end

    def call
      raise ArgumentError, 'Quantity must be positive' unless @quantity.positive?

      @inventory.with_lock do
        raise ArgumentError, 'Insufficient inventory' if @inventory.stock < @quantity

        remaining = allocate_lots
        raise ArgumentError, 'No unexpired stock sufficient for this quantity' if remaining.positive?
      end
    end

    def allocate_lots
      remaining = @quantity
      @inventory.inventory_lots.saleable.lock.each do |lot|
        next if remaining.zero?

        quantity = [remaining, lot.quantity].min
        self.class.consume_lot!(inventory: @inventory, lot:, quantity:, user: @user, kind: @kind, **@options)
        remaining -= quantity
      end
      remaining
    end

    def self.consume_lot!(inventory:, lot:, quantity:, user:, **options)
      inventory.with_lock do
        kind = options.fetch(:kind, 'sale')
        validate_lot!(inventory:, lot:, quantity:, kind:)
        lot.update!(quantity: lot.quantity - quantity)
        consume_serials!(lot, quantity, kind) if inventory.product.tracking_mode == 'serial'
        Inventories::ApplyMovement.call(
          inventory:, quantity: -quantity, kind:, user:,
          inventory_lot: lot, **options.except(:kind)
        )
      end
    end

    def self.validate_lot!(inventory:, lot:, quantity:, kind:)
      return if lot_eligible?(inventory:, lot:, quantity:, kind:)

      raise ArgumentError, 'Lot is not available or has insufficient stock'
    end

    def self.lot_eligible?(inventory:, lot:, quantity:, kind:)
      quantity.positive? && lot.inventory_id == inventory.id && lot.available? &&
        expiration_allowed?(lot, kind) && lot.quantity >= quantity && inventory.stock >= quantity
    end

    def self.expiration_allowed?(lot, kind)
      kind == 'return' || lot.expires_on.nil? || lot.expires_on >= Date.current
    end

    def self.consume_serials!(lot, quantity, kind)
      serials = lot.inventory_serials.available.order(:id).limit(quantity.to_i).to_a
      raise ArgumentError, 'Not enough available serial numbers' unless serials.size == quantity.to_i

      status = kind == 'return' ? :returned : :sold
      serials.each { |serial| serial.update!(status:) }
    end
  end
end
