# frozen_string_literal: true

class InventoryPolicy < ApplicationPolicy
  def index? = member? && readable?
  def show? = index? && accessible_branch?
  def create? = member? && manageable? && accessible_branch?
  def update? = create?
  def adjust? = member? && adjustable? && accessible_branch?

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization = CurrentOrganizationAccess.organization
      return scope.none unless organization && user
      return scope.none unless user.organization_memberships.accessible.exists?(organization:)
      return scope.none unless user.admin? || user.permission?('inventory.access') || user.permission?('inventory.view')

      records = scope.where(organization:)
      return records if user.admin?

      branch_ids = user.user_roles.active.where(organization:).where.not(branch_id: nil).select(:branch_id)
      records.where(branch_id: branch_ids)
    end
  end

  private

  def member?
    organization = CurrentOrganizationAccess.organization
    organization && user && user.organization_memberships.accessible.exists?(organization:)
  end

  def readable?
    user.admin? || user.permission?('inventory.access') || user.permission?('inventory.view')
  end

  def manageable?
    user.admin? || user.permission?('inventory.manage')
  end

  def adjustable?
    user.admin? || user.permission?('inventory.adjust')
  end

  def accessible_branch?
    return true if record == Inventory
    return false unless record.is_a?(Inventory) && record.organization == CurrentOrganizationAccess.organization
    return true if user.admin?

    user.user_roles.active.where(organization: record.organization, branch_id: record.branch_id).exists?
  end
end
