# frozen_string_literal: true

class InventoryPolicy < ApplicationPolicy
  READ_KEYS = %w[inventory.access inventory.view].freeze

  def index? = member? && (user.admin? || self.class.permitted_roles(user, organization, READ_KEYS).exists?)
  def show? = member? && branch_granted?(READ_KEYS)
  def create? = member? && branch_granted?(%w[inventory.manage])
  def update? = create?
  def adjust? = member? && branch_granted?(%w[inventory.adjust])

  # Select only active grants carrying the requested inventory permission.
  # A global role applies across the organization; a branch role applies only
  # to its active branch. Other unrelated branch roles grant no inventory access.
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
      organization = CurrentOrganizationAccess.organization
      return scope.none unless organization && user
      return scope.none unless user.organization_memberships.accessible.exists?(organization:)

      records = scope.where(organization:)
      return records if user.admin?

      granted = InventoryPolicy.permitted_roles(user, organization, READ_KEYS)
      return records if granted.where(branch_id: nil).exists?

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
        .where(branch_id: [nil, record.branch_id]).exists?
  end
end
