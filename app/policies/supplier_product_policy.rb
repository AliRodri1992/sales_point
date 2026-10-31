# frozen_string_literal: true

class SupplierProductPolicy < SupplierPolicy
  def index? = view_products?
  def show? = index?
  def create? = create_products?
  def new? = create?
  def edit? = update_products?
  def update? = update_products?
  def destroy? = destroy_products?
  def restore? = restore_products?

  class Scope < SupplierPolicy::Scope
  end
end
