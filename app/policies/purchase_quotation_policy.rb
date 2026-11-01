# frozen_string_literal: true

class PurchaseQuotationPolicy < PurchaseOrderPolicy
  def accept? = organization_access? && permitted?('purchases.approve')
  def reject? = accept?

  class Scope < PurchaseOrderPolicy::Scope
  end
end
