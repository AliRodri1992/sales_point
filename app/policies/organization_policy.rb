# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    user&.role?('super_admin')
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.where(deleted_at: nil) if user&.role?('super_admin')
      return scope.where(deleted_at: nil).where(id: user.organization_memberships.active.select(:organization_id)) if user&.admin?

      scope.none
    end
  end

  private

  def admin?
    user&.admin?
  end
end
