# frozen_string_literal: true

class AddReturnStockDisposition < ActiveRecord::Migration[8.1]
  def change
    add_column :purchase_return_items, :stock_disposition, :string,
               null: false, default: 'accepted'
    add_check_constraint :purchase_return_items,
                         "stock_disposition IN ('accepted', 'quarantined')",
                         name: 'chk_purchase_return_stock_disposition'
  end
