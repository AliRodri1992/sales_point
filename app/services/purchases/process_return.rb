# frozen_string_literal: true

module Purchases
  class ProcessReturn
    def self.call(purchase_return:, user:)
      purchase_return.with_lock do
        raise ArgumentError, 'Return already finalized' unless purchase_return.draft?
        raise ArgumentError, 'Return requires items' if purchase_return.purchase_return_items.empty?

        purchase_return.purchase_return_items.each { |line| return_line!(line, user:) }
        purchase_return.update!(status: :processed, processed_at: Time.current)
      end
    end

    def self.return_line!(entry, user:)
      validate_available_return!(entry)
      remaining = entry.quantity
      entry.goods_receipt_item.inventory_lots.available.order(:id).each do |lot|
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

    def self.validate_available_return!(entry)
      past_returns = PurchaseReturnItem.joins(:purchase_return)
                                      .where(goods_receipt_item: entry.goods_receipt_item,
                                             purchase_returns: { status: 'processed' })
                                      .sum(:quantity)
      return unless entry.quantity + past_returns > entry.goods_receipt_item.accepted_quantity

      raise ArgumentError, 'Return exceeds accepted merchandise'
    end
  end
end
