# frozen_string_literal: true

class MembershipPlanPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.where(deleted_at: nil) if user&.admin?

      scope.none
    end
  end

  private

  def admin?
    user&.admin?
  end
end
