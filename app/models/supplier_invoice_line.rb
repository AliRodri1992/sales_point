# frozen_string_literal: true

class SupplierInvoiceLine < ApplicationRecord
  belongs_to :supplier_invoice
  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, :amount, numericality: { greater_than_or_equal_to: 0 }
end
