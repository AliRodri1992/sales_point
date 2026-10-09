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
    admin?
  end

  def destroy?
    admin?
  end

  def update_permissions?
    admin?
  end

  private

  def admin?
    user&.admin?
  end
end
