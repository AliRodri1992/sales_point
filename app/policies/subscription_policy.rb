# frozen_string_literal: true

class SubscriptionPolicy < ApplicationPolicy
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
    false
  end

  def change_plan?
    admin?
  end

  def pause?
    admin?
  end

  def resume?
    admin?
  end

  def cancel?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      scope.none
    end
  end

  private

  def admin?
    user&.admin?
  end
end
