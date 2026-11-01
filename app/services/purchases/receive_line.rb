# frozen_string_literal: true

module Purchases
  class ReceiveLine
    def self.call(receipt:, data:)
      line = receipt.purchase_order.purchase_order_items.find(data.fetch(:purchase_order_item_id))
      quantities = parsed_quantities(data)
      validate_quantities!(order: receipt.purchase_order, line:, **quantities)
      item = save_item(receipt:, line:, data:, quantities:)
      Purchases::ReceiveStock.call(item:, data:) if quantities[:accepted].positive? || quantities[:damaged].positive?
      item
    end

    def self.parsed_quantities(data)
      {
        delivered: BigDecimal(data.fetch(:delivered_quantity).to_s),
        accepted: BigDecimal(data.fetch(:accepted_quantity).to_s),
        damaged: BigDecimal(data.fetch(:damaged_quantity, 0).to_s)
      }
    end

    def self.save_item(receipt:, line:, data:, quantities:)
      receipt.goods_receipt_items.create!(
        purchase_order_item: line, delivered_quantity: quantities[:delivered], accepted_quantity: quantities[:accepted],
        damaged_quantity: quantities[:damaged], lot_code: data[:lot_code],
        expires_on: data[:expires_on], notes: data[:notes]
      )
    end

    def self.validate_quantities!(order:, line:, delivered:, accepted:, damaged:)
      quantities = [delivered, accepted, damaged]
      raise ArgumentError, 'Invalid receiving quantities' unless quantities.all? { |value| value >= 0 }

      raise ArgumentError, 'Accepted and damaged exceed delivery' if accepted + damaged > delivered
      raise ArgumentError, 'Delivery quantity must be positive' unless delivered.positive?
      raise ArgumentError, 'Cannot over-receive an order' if accepted > order.outstanding_quantity_for(line)
    end
  end
end
