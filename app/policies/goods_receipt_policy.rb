# frozen_string_literal: true

class GoodsReceiptPolicy < PurchaseOrderPolicy
  def index? = organization_access? && permitted?('purchases.view')
  def show? = index?
  def create? = organization_access? && permitted?('purchases.receive')
  def new? = create?
  def edit? = false
  def update? = false

  class Scope < PurchaseOrderPolicy::Scope
  end
end
