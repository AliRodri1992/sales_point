# frozen_string_literal: true

class SupplierProductPolicy < SupplierPolicy
  def index? = authorized_record? && allowed?('suppliers.products.view')
  def show? = index?
  def create? = authorized_record? && allowed?('suppliers.products.manage')
  def new? = create?
  def edit? = create?
  def update? = create?
  def destroy? = create?

  class Scope < SupplierPolicy::Scope
  end
end
