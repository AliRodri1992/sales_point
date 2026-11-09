# frozen_string_literal: true

class SystemRolePolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    global_manager?
  end

  def update?
    global_manager? && !protected_role? && !record.deprecated?
  end

  def destroy?
    change_status?
  end

  def update_permissions?
    update?
  end

  def audit_history?
    global_manager?
  end

  def change_status?
    global_manager? && !protected_role?
  end

  private

  def global_manager?
    user&.admin? && user.role?('super_admin')
  end

  def protected_role?
    record.is_a?(SystemRole) && record.protected_permissions?
  end

  def admin?
    user&.admin?
  end
end
