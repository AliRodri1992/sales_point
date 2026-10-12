# frozen_string_literal: true

module Purchases
  class Costing
    def self.apply!(receipt)
      receipt.goods_receipt_items.includes(:purchase_order_item).each do |entry|
        allocate!(entry)
      end
    end

    def self.allocate!(entry)
      order = entry.goods_receipt.purchase_order
      goods = goods_cost(entry)
      weight = cost_weight(order:, entry:, goods:)
      freight = (order.freight_amount * weight).round(6)
      insurance = (order.insurance_amount * weight).round(6)
      landed = landed_cost(entry:, goods:, freight:, insurance:, exchange_rate: order.exchange_rate)
      entry.update!(landed_unit_cost: landed)
      entry.create_purchase_cost_allocation!(
        organization: order.organization, goods_amount: goods.round(6),
        freight_amount: freight, insurance_amount: insurance, landed_unit_cost: landed
      )
    end

    def self.goods_cost(entry)
      line = entry.purchase_order_item
      line.line_total * (entry.accepted_quantity / line.quantity)
    end

    def self.cost_weight(order:, entry:, goods:)
      goods_total = order.goods_total
      return goods / goods_total if goods_total.positive?

      total_quantity = order.purchase_order_items.sum(:quantity)
      total_quantity.positive? ? entry.accepted_quantity / total_quantity : 0
    end

    def self.landed_cost(entry:, goods:, freight:, insurance:, exchange_rate:)
      return 0 unless entry.accepted_quantity.positive?

      ((goods + freight + insurance) * exchange_rate / entry.accepted_quantity).round(6)
    end
  end
end
