# frozen_string_literal: true

class AddSupplierForeignTaxId < ActiveRecord::Migration[8.1]
  def change
    add_column :suppliers, :foreign_tax_id, :string, limit: 80
  end
end
