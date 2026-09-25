# frozen_string_literal: true

class BranchPolicy < ApplicationPolicy
  def index?
    admin? || branch_access?
  end

  def show?
    manage_assigned_branch?
  end

  def create?
    admin?
  end

  def update?
    manage_assigned_branch?
  end

  def destroy?
    manage_assigned_branch?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.where(deleted_at: nil) if user.admin?

      scope
        .where(deleted_at: nil)
        .where(id: active_branch_ids)
    end

    private

    def active_branch_ids
      user.user_roles.active.where.not(branch_id: nil).select(:branch_id)
    end
  end

  private

  def admin?
    user&.admin?
  end

  def branch_access?
    return false unless user

    user.user_roles.active.where.not(branch_id: nil).exists?
  end

  def manage_assigned_branch?
    return false unless record.is_a?(Branch)

    admin? || user.user_roles.active.where(branch_id: record.id).exists?
  end
end
