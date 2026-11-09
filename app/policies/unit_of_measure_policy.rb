# frozen_string_literal: true

class UnitOfMeasurePolicy < CatalogPolicy
  self.permission_prefix = 'units_of_measure'

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization = CurrentOrganizationAccess.organization
      organization ? scope.where(organization_id: organization.id, deleted_at: nil) : scope.none
    end
  end
end
