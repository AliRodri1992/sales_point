# frozen_string_literal: true

class AddSupplierCommercialProfile < ActiveRecord::Migration[8.1]
  def change
    change_table :suppliers, bulk: true do |t|
      t.string :legal_name, limit: 150
      t.string :trade_name, limit: 150
      t.string :alias_name, limit: 100
      t.string :classification, limit: 30
      t.string :person_type, limit: 20
      t.integer :credit_days, default: 0, null: false
      t.decimal :credit_limit, precision: 15, scale: 2, default: 0, null: false
      t.decimal :discount_percent, precision: 5, scale: 2, default: 0, null: false
      t.decimal :minimum_order_amount, precision: 15, scale: 2, default: 0, null: false
    end

    add_reference :suppliers, :currency, null: false, foreign_key: true

    add_check_constraint :suppliers, 'credit_days BETWEEN 0 AND 365', name: 'chk_supplier_credit_days'
    add_check_constraint :suppliers, 'credit_limit >= 0 AND minimum_order_amount >= 0',
                         name: 'chk_supplier_amounts'
    add_check_constraint :suppliers, 'discount_percent BETWEEN 0 AND 100', name: 'chk_supplier_discount'
  end
end
