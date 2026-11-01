# frozen_string_literal: true

class SupplierPaymentPolicy < FinancialPolicy
  def post? = apply?
end
