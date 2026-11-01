# frozen_string_literal: true

class RemoveLegacySupplierBankNumbers < ActiveRecord::Migration[8.1]
  def change
    remove_column :supplier_bank_accounts, :account_number, :string
    remove_column :supplier_bank_accounts, :card_number, :string
    remove_column :supplier_bank_accounts, :card_last_four, :string, limit: 4
  end
end
