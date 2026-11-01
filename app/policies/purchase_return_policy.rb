# frozen_string_literal: true

class PurchaseReturnPolicy < PurchaseOrderPolicy
  def index? = organization_access? && permitted?('purchases.view')
  def show? = index?
  def create? = organization_access? && permitted?('purchases.returns')
  def new? = create?
  def process? = create?

  class Scope < PurchaseOrderPolicy::Scope
  end
end
