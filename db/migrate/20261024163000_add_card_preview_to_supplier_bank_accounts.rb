# frozen_string_literal: true

class AddCardPreviewToSupplierBankAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_bank_accounts, :card_last_four, :string, limit: 4
    add_column :supplier_bank_accounts, :card_expiration_month, :integer
    add_column :supplier_bank_accounts, :card_expiration_year, :integer
  end
end
