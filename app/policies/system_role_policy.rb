# frozen_string_literal: true

class SystemRolePolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    global_manager? || (admin? && user.permission?('roles.create'))
  end

  def update?
    global_manager? && tenant_confined_role? && editable_role?
  end

  def destroy?
    change_status?
  end

  def update_permissions?
    admin? && tenant_confined_role?(SystemRole::ADMINISTRATIVE_CODES) && editable_role?
  end

  def audit_history?
    global_manager? && tenant_confined_role?
  end

  def change_status?
    global_manager? && tenant_confined_role? && !protected_role?
  end

  private

  def global_manager?
    authorized_administrative_role?('super_admin')
  end

  def admin?
    authorized_administrative_role?(SystemRole::ADMINISTRATIVE_CODES)
  end

  def authorized_administrative_role?(codes)
    return false unless active_actor_with_tenant?

    memberships = user.organization_memberships.accessible.select(:organization_id)
    assignments = user.user_roles.active.where(branch_id: nil, organization_id: memberships)
                      .joins(:system_role).where(system_roles: { code: codes })
    organization = CurrentOrganizationAccess.organization
    assignments = assignments.where(organization:) if organization
    assignments.exists?
  end

  def active_actor_with_tenant?
    return false unless user&.active? && user.deleted_at.nil?

    !CurrentOrganizationAccess.enforce_tenant || CurrentOrganizationAccess.organization.present?
  end

  # Role definitions and their permissions are shared across organizations.
  # An organization administrator must never change grants used in another tenant.
  # Legacy unscoped grants are not effective within a tenant and are ignored.
  def tenant_confined_role?(codes = 'super_admin')
    return true unless record.is_a?(SystemRole) && record.persisted?

    current = CurrentOrganizationAccess.organization
    organization_id = current&.id || authorized_administrative_organization_id(codes)
    return false unless organization_id

    record.user_roles.where.not(organization_id: nil)
          .where.not(organization_id:).none?
  end

  def authorized_administrative_organization_id(codes)
    user.user_roles.active.where(branch_id: nil)
        .joins(:system_role).where(system_roles: { code: codes })
        .where(organization_id: user.organization_memberships.accessible.select(:organization_id))
        .pick(:organization_id)
  end

  def protected_role?
    record.is_a?(SystemRole) && record.protected_permissions?
  end

  def editable_role?
    !protected_role? && !record.deprecated? && record.deleted_at.nil?
  end
end
