# frozen_string_literal: true

module Purchases
  class Receive
    def self.call(order:, user:, idempotency_key:, entries:, notes: nil)
      existing = GoodsReceipt.find_by(organization: order.organization, idempotency_key:)
      return existing if existing

      order.with_lock do
        found = GoodsReceipt.find_by(organization: order.organization, idempotency_key:)
        return found if found

        raise ArgumentError, 'Order must be sent before receiving' unless order.receivable?
        raise ArgumentError, 'Receipt must contain items' if entries.blank?

        receipt = GoodsReceipt.create!(
          organization: order.organization, branch: order.branch, purchase_order: order,
          received_by: user, idempotency_key:, notes:, received_at: Time.current
        )
        entries.each { |entry| receive_line!(receipt, entry.symbolize_keys) }
        raise ArgumentError, 'Receipt has no quantities' unless receipt.goods_receipt_items.exists?

        Purchases::Costing.apply!(receipt)
        update_order_status!(order)
        receipt
      end
    rescue ActiveRecord::RecordNotUnique
      GoodsReceipt.find_by!(organization: order.organization, idempotency_key:)
    end

    def self.receive_line!(receipt, data)
      line = receipt.purchase_order.purchase_order_items.find(data.fetch(:purchase_order_item_id))
      delivered = BigDecimal(data.fetch(:delivered_quantity).to_s)
      accepted = BigDecimal(data.fetch(:accepted_quantity).to_s)
      damaged = BigDecimal(data.fetch(:damaged_quantity, 0).to_s)
      raise ArgumentError, 'Invalid receiving quantities' if [delivered, accepted, damaged].any?(&:negative?)
      raise ArgumentError, 'Accepted and damaged exceed delivery' if accepted + damaged > delivered
      raise ArgumentError, 'Cannot over-receive an order' if accepted > receipt.purchase_order.outstanding_quantity_for(line)

      item = receipt.goods_receipt_items.create!(
        purchase_order_item: line, delivered_quantity: delivered,
        accepted_quantity: accepted, damaged_quantity: damaged,
        lot_code: data[:lot_code], expires_on: data[:expires_on], notes: data[:notes]
      )
      return if accepted.zero?

      record_stock!(receipt, item, data)
    end

    def self.record_stock!(receipt, item, data)
      line = item.purchase_order_item
      inventory = Inventory.find_or_create_by!(
        organization: receipt.organization, branch: receipt.branch, product: line.product
      )
      tracking = line.product.tracking_mode
      if tracking == 'lot' && item.lot_code.blank?
        raise ArgumentError, 'Lot number required for lot-tracked products'
      end
      if tracking.in?(%w[lot serial]) && item.expires_on.present? && item.expires_on < Date.current
        raise ArgumentError, 'Cannot receive expired stock'
      end
      serial_numbers = Array(data[:serial_numbers]).flat_map { |v| v.to_s.split(/[\s,;]+/) }.reject(&:blank?)
      validate_serials!(tracking, serial_numbers, item.accepted_quantity)

      lot = inventory.inventory_lots.create!(
        organization: receipt.organization, goods_receipt_item: item,
        code: "#{item.lot_code.presence || 'RCV'}-#{item.id}", expires_on: item.expires_on,
        quantity: item.accepted_quantity, status: :available
      )
      serial_numbers.each do |number|
        lot.inventory_serials.create!(organization: receipt.organization, serial_number: number)
      end
      Inventories::ApplyMovement.call(inventory:, quantity: item.accepted_quantity,
                                      kind: 'receipt', user: receipt.received_by, source: item, inventory_lot: lot)
    end

    def self.validate_serials!(tracking, values, amount)
      return if tracking != 'serial' && values.empty?

      unless tracking == 'serial' && amount.frac.zero? && values.size == amount.to_i && values.uniq.size == values.size
        raise ArgumentError, 'Serial numbers must match accepted individual units'
      end
    end

    def self.update_order_status!(order)
      completed = order.purchase_order_items.all? { |line| order.outstanding_quantity_for(line).zero? }
      order.update!(status: completed ? :received : :partially_received)
    end
  end
end
