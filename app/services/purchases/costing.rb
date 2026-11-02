# frozen_string_literal: true

module Purchases
  class Costing
    def self.apply!(receipt)
      order = receipt.purchase_order
      entries = receipt.goods_receipt_items.includes(:purchase_order_item).to_a
      order_items = order.purchase_order_items.to_a
      totals = {
        order_goods: order_items.sum(&:line_total),
        order_quantity: order_items.sum(&:quantity),
        receipt_goods: entries.sum { |entry| goods_cost(entry) },
        receipt_quantity: entries.sum(&:accepted_quantity)
      }
      entries.each { |entry| allocate!(entry, receipt:, order:, totals:) }
    end

    def self.allocate!(entry, receipt: nil, order: nil, totals: nil)
      receipt ||= entry.goods_receipt
      order ||= receipt.purchase_order
      goods = goods_cost(entry)
      receipt_weight = weight_in_receipt(entry, goods, totals:)
      order_weight = weight_in_order(order, entry, goods, totals:)

      costs = expenses(receipt, order, receipt_weight, order_weight)
      landed = landed_cost(entry:, goods:, exchange_rate: order.exchange_rate, **costs)
      entry.update!(landed_unit_cost: landed)
      entry.create_purchase_cost_allocation!(
        organization: order.organization, goods_amount: goods.round(6),
        landed_unit_cost: landed, freight_amount: costs[:freight], insurance_amount: costs[:insurance],
        extra_expenses_amount: costs[:extra_expenses],
        additional_discount_amount: costs[:additional_discount]
      )
    end

    def self.goods_cost(entry)
      line = entry.purchase_order_item
      line.line_total * (entry.accepted_quantity / line.quantity)
    end

    def self.weight_in_order(order, entry, goods, totals: nil)
      total = totals ? totals.fetch(:order_goods) : order.goods_total
      return goods / total if total.positive?

      quantity = totals ? totals.fetch(:order_quantity) : order.purchase_order_items.sum(:quantity)
      quantity.positive? ? entry.accepted_quantity / quantity : 0
    end

    def self.weight_in_receipt(entry, goods, totals: nil)
      if totals
        total = totals.fetch(:receipt_goods)
        quantity = totals.fetch(:receipt_quantity)
      else
        receipt_items = entry.goods_receipt.goods_receipt_items.includes(:purchase_order_item)
        total = receipt_items.sum { |item| goods_cost(item) }
        quantity = receipt_items.sum(&:accepted_quantity)
      end
      return goods / total if total.positive?

      quantity.positive? ? entry.accepted_quantity / quantity : 0
    end

    def self.expenses(receipt, order, receipt_weight, order_weight)
      {
        freight: cost_share(receipt.actual_freight_amount, order.freight_amount, receipt_weight, order_weight),
        insurance: cost_share(receipt.actual_insurance_amount, order.insurance_amount, receipt_weight, order_weight),
        extra_expenses: (receipt.extra_expenses_amount * receipt_weight).round(6),
        additional_discount: (receipt.additional_discount_amount * receipt_weight).round(6)
      }
    end

    def self.cost_share(actual, estimate, receipt_weight, order_weight)
      ((actual.nil? ? estimate * order_weight : actual * receipt_weight)).round(6)
    end

    def self.landed_cost(entry:, goods:, exchange_rate:, **costs)
      return 0 unless entry.accepted_quantity.positive?

      amount = goods + costs.fetch(:freight) + costs.fetch(:insurance) +
               costs.fetch(:extra_expenses, 0) - costs.fetch(:additional_discount, 0)
      raise ArgumentError, 'Receipt discount exceeds accepted value' if amount.negative?

      (amount * exchange_rate / entry.accepted_quantity).round(6)
    end
  end
end
