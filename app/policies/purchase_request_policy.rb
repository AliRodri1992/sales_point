# frozen_string_literal: true

class PurchaseRequestPolicy < PurchaseOrderPolicy
  def approve? = organization_access? && permitted?('purchases.approve')
  def reject? = approve?
  def cancel? = create?

  class Scope < PurchaseOrderPolicy::Scope
  end
end
