# frozen_string_literal: true

class CategoryPolicy < CatalogPolicy
  self.permission_prefix = 'categories'

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization = CurrentOrganizationAccess.organization
      organization ? scope.where(organization_id: organization.id) : scope.none
    end
  end
end
