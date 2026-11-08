# frozen_string_literal: true

module Inventories
  class ApplyMovement
    def self.call(inventory:, quantity:, kind:, **options)
      inventory.branch.with_lock do
        operation = kind.to_s
        permitted = case inventory.branch.operational_status
                    when 'active' then true
                    when 'preparing' then operation == 'adjustment'
                    when 'suspended' then operation != 'sale'
                    else false
                    end
        unless permitted
          inventory.errors.add(:branch, :invalid)
          raise ActiveRecord::RecordInvalid, inventory
        end
        inventory.with_lock do
        amount = BigDecimal(quantity.to_s)
        validate_movement!(inventory:, amount:, kind:, lot: options[:inventory_lot])
        before = inventory.stock
        after = before + amount
        raise ActiveRecord::RecordInvalid, inventory if after.negative?

        inventory.update!(stock: after)
        inventory.inventory_movements.create!(
          organization: inventory.organization, user: options[:user], kind:,
          reference: options[:reference], source: options[:source],
          inventory_lot: options[:inventory_lot],
          quantity: amount, stock_before: before, stock_after: after
        )
        end
      end
    end

    def self.validate_movement!(inventory:, amount:, kind:, lot:)
      raise ArgumentError, 'Quantity must not be zero' if amount.zero?
      raise ArgumentError, 'Invalid movement kind' unless InventoryMovement::KINDS.include?(kind)

      validate_tracking!(inventory:, lot:)
    end

    def self.validate_tracking!(inventory:, lot:)
      raise ArgumentError, 'Inventory lot belongs to another inventory' if lot && lot.inventory_id != inventory.id

      return if inventory.product.tracking_none? || lot

      raise ArgumentError, 'Tracked inventory requires a lot-specific stock movement'
    end
  end
end
