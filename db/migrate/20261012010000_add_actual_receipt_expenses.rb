# frozen_string_literal: true

class AddActualReceiptExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :goods_receipts, :actual_freight_amount, :decimal, precision: 14, scale: 4
    add_column :goods_receipts, :actual_insurance_amount, :decimal, precision: 14, scale: 4
    add_column :goods_receipts, :extra_expenses_amount, :decimal, precision: 14, scale: 4, default: 0, null: false
    add_column :goods_receipts, :additional_discount_amount, :decimal, precision: 14, scale: 4, default: 0,
               null: false
    add_column :purchase_cost_allocations, :extra_expenses_amount, :decimal, precision: 18, scale: 6,
               default: 0, null: false
    add_column :purchase_cost_allocations, :additional_discount_amount, :decimal, precision: 18, scale: 6,
               default: 0, null: false

    add_check_constraint :goods_receipts,
                         '(actual_freight_amount IS NULL OR actual_freight_amount >= 0) AND ' \
                         '(actual_insurance_amount IS NULL OR actual_insurance_amount >= 0) AND ' \
                         'extra_expenses_amount >= 0 AND additional_discount_amount >= 0',
                         name: 'chk_goods_receipts_actual_costs'
  end
end
