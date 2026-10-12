# frozen_string_literal: true

module Purchases
  class Costing
    def self.apply!(receipt)
      order = receipt.purchase_order
      items = receipt.goods_receipt_items.includes(:purchase_order_item)
      total = order.goods_total
      allocation_basis = total.positive? ? total : order.purchase_order_items.sum(:quantity)

      items.each do |entry|
        line = entry.purchase_order_item
        fraction = entry.accepted_quantity / line.quantity
        goods = line.line_total * fraction
        weight = allocation_basis.positive? ? (total.positive? ? goods : entry.accepted_quantity) / allocation_basis : 0
        freight = (order.freight_amount * weight).round(6)
        insurance = (order.insurance_amount * weight).round(6)
        unit_cost = if entry.accepted_quantity.positive?
                      ((goods + freight + insurance) * order.exchange_rate / entry.accepted_quantity).round(6)
                    else
                      0
                    end
        entry.update!(landed_unit_cost: unit_cost)
        entry.create_purchase_cost_allocation!(
          organization: receipt.organization, goods_amount: goods.round(6),
          freight_amount: freight, insurance_amount: insurance, landed_unit_cost: unit_cost
        )
      end
    end
  end
end
