# frozen_string_literal: true

class CategoryPolicy < CatalogPolicy
  self.permission_prefix = 'categories'

  def references?
    return @references if defined?(@references)

    @references = update? && ProductPolicy.new(user, Product).update? && PromotionPolicy.new(user, Promotion).update?
  end

  def reassign? = references?

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization = CurrentOrganizationAccess.organization
      organization ? scope.where(organization_id: organization.id) : scope.none
    end
  end
end
