# frozen_string_literal: true

class AddSatVerificationToSupplierInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_invoices, :sat_status, :string, limit: 30
    add_column :supplier_invoices, :sat_response_code, :string, limit: 120
    add_column :supplier_invoices, :sat_verified_at, :datetime
  end
end
