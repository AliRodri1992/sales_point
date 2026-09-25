# frozen_string_literal: true

class BranchPolicy < ApplicationPolicy
  def index?
    admin? || branch_access?
  end

  def show?
    admin? || assigned_to_branch?
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
      active_branches = scope.not_deleted
      return active_branches if user.admin?

      active_branches.where(id: active_branch_ids)
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

  def assigned_to_branch?
    return false unless user && record.is_a?(Branch)

    user.user_roles.active.exists?(branch_id: record.id)
  end
end
