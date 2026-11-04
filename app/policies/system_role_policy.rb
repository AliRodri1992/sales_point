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
    admin? && !protected_role? && !record.deprecated?
  end

  def destroy?
    change_status?
  end

  def update_permissions?
    update?
  end

  def change_status?
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
