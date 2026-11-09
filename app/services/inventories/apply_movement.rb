# frozen_string_literal: true

module Inventories
  class ApplyMovement
    def self.call(inventory:, quantity:, kind:, **options)
      inventory.branch.with_lock do
        amount = BigDecimal(quantity.to_s)
        validate_branch_status!(inventory, kind, amount:, **options)
        inventory.with_lock { record_movement(inventory:, amount:, kind:, options:) }
      end
    end

    def self.record_movement(inventory:, amount:, kind:, options:)
      validate_movement!(inventory:, amount:, kind:, lot: options[:inventory_lot])
      reconcile_adjusted_lot!(inventory:, amount:, kind:, lot: options[:inventory_lot])
      before = inventory.stock
      after_stock = before + amount
      raise ActiveRecord::RecordInvalid, inventory if after_stock.negative?

      inventory.update!(stock: after_stock)
      inventory.inventory_movements.create!(
        organization: inventory.organization, user: options[:user], kind:,
        reference: options[:reference], source: options[:source],
        inventory_lot: options[:inventory_lot],
        quantity: amount, stock_before: before, stock_after: after_stock
      )
    end

    def self.validate_branch_status!(inventory, kind, amount:, **options)
      permitted = case inventory.branch.operational_status
                  when 'active' then inventory.branch.operationally_active?
                  when 'preparing' then kind.to_s == 'adjustment'
                  when 'suspended' then suspended_movement?(inventory, kind, amount, options)
                  else false
                  end
      return if permitted

      inventory.errors.add(:branch, :invalid)
      raise ActiveRecord::RecordInvalid, inventory
    end

    def self.suspended_movement?(inventory, kind, amount, options)
      return false unless inventory.branch.organization&.active?
      return false unless amount.negative?

      case kind.to_s
      when 'adjustment' then authorized_adjustment?(inventory, options[:user])
      when 'return'
        authorized_branch_operator?(inventory, options[:user]) &&
          established_supplier_return?(inventory, options[:source])
      else false # No new receipts, transfers, or sales during suspension.
      end
    end

    def self.authorized_adjustment?(inventory, user)
      user&.admin? && user.organization_memberships.accessible
                          .exists?(organization_id: inventory.organization_id)
    end

    def self.authorized_branch_operator?(inventory, user)
      return false unless user

      user.organization_memberships.accessible.exists?(organization_id: inventory.organization_id)
    end

    def self.established_supplier_return?(inventory, source)
      return false unless source.is_a?(PurchaseReturnItem) && source.persisted?

      item = source.goods_receipt_item
      receipt = item&.goods_receipt
      suspension_at = inventory.branch.branch_status_transitions
                               .where(to_status: 'suspended').order(created_at: :desc).pick(:created_at)
      return false unless receipt && item.persisted? && suspension_at

      receipt.branch_id == inventory.branch_id &&
        receipt.created_at <= suspension_at && item.created_at <= suspension_at &&
        item.purchase_order_item&.product_id == inventory.product_id &&
        source.purchase_return&.goods_receipt_id == receipt.id
    end

    def self.reconcile_adjusted_lot!(inventory:, amount:, kind:, lot:)
      return unless kind.to_s == 'adjustment' && lot

      raise ArgumentError, 'Serialized stock requires serial-level reconciliation' if inventory.product.tracking_serial?
      raise ArgumentError, 'Quarantined lots require separate reconciliation' if lot.quarantined?

      lot.with_lock do
        new_quantity = lot.quantity + amount
        raise ArgumentError, 'Lot quantity cannot become negative' if new_quantity.negative?

        status = new_quantity.zero? ? :depleted : (lot.depleted? ? :available : lot.status)
        lot.update!(quantity: new_quantity, status:)
      end
    end

    def self.validate_movement!(inventory:, amount:, kind:, lot:)
      raise ArgumentError, 'Quantity must not be zero' if amount.zero?
      raise ArgumentError, 'Invalid movement kind' unless InventoryMovement::KINDS.include?(kind)

      validate_tracking!(inventory:, lot:)
    end

    def self.validate_tracking!(inventory:, lot:)
      raise ArgumentError, 'Inventory lot belongs to another inventory' if lot && lot.inventory_id != inventory.id

      return if lot || (inventory.product.tracking_none? && !inventory.inventory_lots.exists?)

      raise ArgumentError, 'Inventory with recorded lots requires a lot-specific stock movement'
    end
  end
end
