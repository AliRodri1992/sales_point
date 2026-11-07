# frozen_string_literal: true

class BranchPolicy < ApplicationPolicy
  def index?
    admin? || branch_access?
  end

  def show?
    managed_branch? || assigned_to_branch?
  end

  def create?
    admin? && (record == Branch || managed_branch?)
  end

  def update? = managed_branch?
  def destroy? = managed_branch?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      organization_ids = user.organization_memberships.accessible.select(:organization_id)
      branches = scope.not_deleted.where(organization_id: organization_ids)
      return branches if user.admin?

      branches.where(id: user.user_roles.active.where.not(branch_id: nil).select(:branch_id))
    end
  end

  private

  def admin?
    user&.admin?
  end

  def managed_branch?
    admin? && record.is_a?(Branch) && member_of_branch_organization?
  end

  def member_of_branch_organization?
    user.organization_memberships.accessible.exists?(organization_id: record.organization_id)
  end

  def branch_access?
    return false unless user

    user.user_roles.active.where.not(branch_id: nil).exists?
  end

  def assigned_to_branch?
    return false unless user && record.is_a?(Branch)

    member_of_branch_organization? && user.user_roles.active.exists?(branch_id: record.id)
  end
end
