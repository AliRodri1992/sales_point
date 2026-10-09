# frozen_string_literal: true

class CategoryPolicy < ApplicationPolicy
  def index?
    user.permission?('categories.access')
  end

  def show?
    user.permission?('categories.access')
  end

  def create?
    user.permission?('categories.access')
  end

  def update?
    user.permission?('categories.access')
  end

  def destroy?
    user.permission?('categories.access')
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
