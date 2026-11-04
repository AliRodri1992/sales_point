# frozen_string_literal: true

class CategoryPolicy < CatalogPolicy
  self.permission_prefix = 'categories'

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
