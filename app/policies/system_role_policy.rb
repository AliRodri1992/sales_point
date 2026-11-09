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
    authorized_administrative_role?('super_admin')
  end

  def admin?
    authorized_administrative_role?(SystemRole::ADMINISTRATIVE_CODES)
  end

  def authorized_administrative_role?(codes)
    return false unless user&.active? && user.deleted_at.nil?

    memberships = user.organization_memberships.accessible.select(:organization_id)
    assignments = user.user_roles.active.where(branch_id: nil, organization_id: memberships)
                      .joins(:system_role).where(system_roles: { code: codes })
    organization = CurrentOrganizationAccess.organization
    assignments = assignments.where(organization:) if organization
    assignments.exists?
  end

  def protected_role?
    record.is_a?(SystemRole) && record.protected_permissions?
  end
end
