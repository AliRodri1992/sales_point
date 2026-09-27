# frozen_string_literal: true

class AddPosIndexes < ActiveRecord::Migration[8.1]
  def change
    # Products indices for POS operations
    add_index :products, :category_id, where: '(deleted_at IS NULL)'
    add_index :products, :sat_tax_id, where: '(deleted_at IS NULL)'
    add_index :products, :sat_unit_key_id, where: '(deleted_at IS NULL)'
    add_index :products, :status, where: '(deleted_at IS NULL)'

    # Clients indices for POS operations
    add_index :clients, :sat_fiscal_regime_id, where: 'deleted_at IS NULL'

    # Messages indices for POS operations
    add_index :messages, :user_id, where: 'deleted_at IS NULL'
  end
end
