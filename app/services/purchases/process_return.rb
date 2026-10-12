# frozen_string_literal: true

module Purchases
  class ProcessReturn
    def self.call(purchase_return:, user:)
      purchase_return.with_lock do
        raise ArgumentError, 'Return is already finalized' unless purchase_return.draft?
        raise ArgumentError, 'Return requires items' if purchase_return.purchase_return_items.empty?

        purchase_return.purchase_return_items.each { |entry| return_line!(entry, user:) }
        purchase_return.update!(status: :processed, processed_at: Time.current)
      end
    end

    def self.return_line!(entry, user:)
      receipt_item = entry.goods_receipt_item
      returned_before = PurchaseReturnItem.joins(:purchase_return)
                                          .where(goods_receipt_item: receipt_item,
                                                 purchase_returns: { status: 'processed' }).sum(:quantity)
      if entry.quantity + returned_before > receipt_item.accepted_quantity
        raise ArgumentError, 'Return exceeds accepted merchandise'
      end

      remaining = entry.quantity
      receipt_item.inventory_lots.available.order(:id).each do |lot|
        next if remaining.zero?

        taken = [remaining, lot.quantity].min
        Inventories::FefoAllocator.consume_lot!(
          inventory: lot.inventory, lot:, quantity: taken, user:, source: entry,
          reference: "RETURN-#{entry.purchase_return_id}", kind: 'return'
        )
        remaining -= taken
      end
      raise ArgumentError, 'Not enough received stock remains for return' if remaining.positive?
    end
  end
end
