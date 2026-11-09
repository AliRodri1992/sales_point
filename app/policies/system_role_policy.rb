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
    return false unless user&.active? && user.deleted_at.nil?

    # A legacy role assignment must not grant platform-wide administration
    # after all organization memberships have been revoked.
    organizations = user.organization_memberships.accessible.select(:organization_id)
    assignments = user.user_roles.active.where(branch_id: nil, organization_id: organizations)
                      .joins(:system_role).where(system_roles: { code: 'super_admin' })
    current = CurrentOrganizationAccess.organization
    assignments = assignments.where(organization: current) if current
    assignments.exists?
  end

  def protected_role?
    record.is_a?(SystemRole) && record.protected_permissions?
  end

  def admin?
    user&.admin?
  end
end
