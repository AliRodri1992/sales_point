# frozen_string_literal: true

class InventoryPolicy < ApplicationPolicy
  READ_KEYS = %w[inventory.access inventory.view].freeze

  def index? = member? && (user.admin? || self.class.permitted_roles(user, organization, READ_KEYS).exists?)
  def show? = member? && branch_granted?(READ_KEYS)
  def create? = member? && branch_granted?(%w[inventory.manage])
  def update? = create?
  def adjust? = member? && branch_granted?(%w[inventory.adjust])

  # Global grants cover the tenant; branch grants cover only their active branch.
  def self.permitted_roles(user, organization, keys)
    return UserRole.none unless user && organization

    roles = user.user_roles.active.where(organization:)
                .joins(system_role: :permissions)
                .where(system_role_permissions: { deleted_at: nil },
                       permissions: { code: keys, status: 'active' })
    active_branches = Branch.not_deleted.where(organization:, operational_status: 'active').select(:id)
    roles.where(branch_id: nil).or(roles.where(branch_id: active_branches))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless authorized_member?

      records = scope.where(organization: organization)
      return records if user.admin?

      restrict_to_granted_branches(records)
    end

    private

    def organization = CurrentOrganizationAccess.organization

    def authorized_member?
      user && organization && user.organization_memberships.accessible.exists?(organization:)
    end

    def restrict_to_granted_branches(records)
      granted = InventoryPolicy.permitted_roles(user, organization, READ_KEYS)
      return records if granted.exists?(branch_id: nil)

      records.where(branch_id: granted.where.not(branch_id: nil).select(:branch_id))
    end
  end

  private

  def organization = CurrentOrganizationAccess.organization

  def member?
    organization && user && user.organization_memberships.accessible.exists?(organization:)
  end

  def branch_granted?(keys)
    return false unless record.is_a?(Inventory) && record.organization_id == organization.id
    return true if user.admin?

    self.class.permitted_roles(user, organization, keys)
        .exists?(branch_id: [nil, record.branch_id])
  end
end
