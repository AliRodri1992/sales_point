# frozen_string_literal: true

class ClientPolicy < CatalogPolicy
  self.permission_prefix = 'customers'

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization = CurrentOrganizationAccess.organization
      organization ? scope.where(organization_id: organization.id) : scope.none
    end
  end
end
