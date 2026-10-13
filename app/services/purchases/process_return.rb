# frozen_string_literal: true

module Purchases
  class ProcessReturn
    def self.call(purchase_return:, user:)
      purchase_return.goods_receipt.with_lock do
        purchase_return.with_lock do
          raise ArgumentError, 'Return already finalized' unless purchase_return.draft?
          raise ArgumentError, 'Return requires items' if purchase_return.purchase_return_items.empty?

          purchase_return.purchase_return_items.each { |entry| return_line!(entry, user:) }
          purchase_return.update!(status: :processed, processed_at: Time.current)
        end
      end
    end

    def self.return_line!(entry, user:)
      validate_available_return!(entry)
      if entry.stock_quarantined?
        return_quarantined!(entry)
      else
        return_accepted!(entry, user:)
      end
    end

    def self.return_accepted!(entry, user:)
      remaining = entry.quantity
      lots = entry.goods_receipt_item.inventory_lots.available
                  .where('quantity > 0').order(Arel.sql('expires_on ASC NULLS LAST'), :id)
      lots.each do |lot|
        next if remaining.zero?

        quantity = [remaining, lot.quantity].min
        Inventories::FefoAllocator.consume_lot!(
          inventory: lot.inventory, lot:, quantity:, user:, source: entry,
          reference: "RETURN-#{entry.purchase_return_id}", kind: 'return'
        )
        remaining -= quantity
      end
      raise ArgumentError, 'Not enough stock in received lot' if remaining.positive?
    end

    def self.return_quarantined!(entry)
      remaining = entry.quantity
      entry.goods_receipt_item.inventory_lots.quarantined
           .where('quantity > 0').order(:id).each do |lot|
        next if remaining.zero?

        quantity = [remaining, lot.quantity].min
        lot.with_lock do
          return_quarantined_serials!(lot, quantity)
          updated_quantity = lot.quantity - quantity
          lot.update!(quantity: updated_quantity, status: updated_quantity.zero? ? :depleted : :quarantined)
        end
        remaining -= quantity
      end
      raise ArgumentError, 'Not enough quarantined merchandise to return' if remaining.positive?
    end

    def self.return_quarantined_serials!(lot, quantity)
      return unless lot.inventory.product.tracking_serial?

      raise ArgumentError, 'Serialized quantities must be whole numbers' unless quantity.frac.zero?

      serials = lot.inventory_serials.quarantined.order(:id).limit(quantity.to_i).to_a
      raise ArgumentError, 'Insufficient quarantined serial numbers' unless serials.size == quantity.to_i

      serials.each { |serial| serial.update!(status: :returned) }
    end

    def self.validate_available_return!(entry)
      condition = entry.stock_disposition
      records = PurchaseReturnItem.joins(:purchase_return)
      past_returns = records.where(goods_receipt_item: entry.goods_receipt_item,
                                   stock_disposition: condition,
                                   purchase_returns: { status: 'processed' }).sum(:quantity)
      limit = if entry.stock_quarantined?
                entry.goods_receipt_item.damaged_quantity
              else
                entry.goods_receipt_item.accepted_quantity
              end
      return unless entry.quantity + past_returns > limit

      raise ArgumentError, 'Return exceeds received merchandise in selected condition'
    end
  end
end
