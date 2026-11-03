# frozen_string_literal: true

class AddSatBankCodeIndexToSupplierBankAccounts < ActiveRecord::Migration[8.1]
  def change
    add_index :supplier_bank_accounts, :sat_bank_code,
              name: 'index_supplier_bank_accounts_on_sat_bank_code'
  end
end
