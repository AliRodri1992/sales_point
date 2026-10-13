# frozen_string_literal: true

module Purchases
  class Costing
    def self.apply!(receipt)
      receipt.goods_receipt_items.includes(:purchase_order_item).find_each do |entry|
        allocate!(entry)
      end
    end

    def self.allocate!(entry)
      receipt = entry.goods_receipt
      order = receipt.purchase_order
      goods = goods_cost(entry)
      receipt_weight = weight_in_receipt(entry, goods)
      order_weight = weight_in_order(order, entry, goods)

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

    def self.weight_in_order(order, entry, goods)
      total = order.goods_total
      return goods / total if total.positive?

      quantity = order.purchase_order_items.sum(:quantity)
      quantity.positive? ? entry.accepted_quantity / quantity : 0
    end

    def self.weight_in_receipt(entry, goods)
      receipt_items = entry.goods_receipt.goods_receipt_items.includes(:purchase_order_item)
      total = receipt_items.sum { |item| goods_cost(item) }
      return goods / total if total.positive?

      quantity = receipt_items.sum(&:accepted_quantity)
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
