# frozen_string_literal: true

class PriceListPolicy < CatalogPolicy
  self.permission_prefix = 'products'

  def show?
    permitted_action?(:index) && permitted_action?(:show)
  end

  def create? = user&.admin? || false
  def update? = user&.admin? || false
  def destroy? = user&.admin? || false
end
