# frozen_string_literal: true

module SupplierFinancialAssociations
  extend ActiveSupport::Concern

  included do
    has_many :supplier_bank_accounts, dependent: :restrict_with_exception
    has_many :supplier_invoices, dependent: :restrict_with_exception
    has_many :account_payables, dependent: :restrict_with_exception
    has_many :supplier_payments, dependent: :restrict_with_exception
    has_many :supplier_credit_notes, dependent: :restrict_with_exception
  end
end
