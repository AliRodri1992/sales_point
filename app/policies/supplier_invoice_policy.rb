# frozen_string_literal: true

class SupplierInvoicePolicy < FinancialPolicy
  def download? = show?
end
