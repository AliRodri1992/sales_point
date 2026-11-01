# frozen_string_literal: true

class DemoRequestPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
  end

  def update?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope
    end
  end

  private

  def admin?
    user&.admin?
  end
end
