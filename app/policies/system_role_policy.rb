# frozen_string_literal: true

class SystemRolePolicy < ApplicationPolicy
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
    admin? && !protected_role?
  end

  def destroy?
    admin? && !protected_role?
  end

  def update_permissions?
    admin? && !protected_role?
  end

  private

  def protected_role?
    record.is_a?(SystemRole) && record.protected_permissions?
  end

  def admin?
    user&.admin?
  end
end
