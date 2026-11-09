# frozen_string_literal: true

# Resolves only roles that can currently grant access to the user.
module UserEffectiveRoles
  def role?(role_code, branch: nil, organization: CurrentOrganizationAccess.organization)
    scope = effective_role_assignments(organization:).where(system_roles: { code: role_code })
    scope = scope.where(branch:) if branch
    scope.exists?
  end

  def permission?(permission_code, organization: CurrentOrganizationAccess.organization)
    effective_permission_scope(organization:).exists?(permissions: { code: permission_code, status: 'active' })
  end

  def effective_permission_codes(organization: CurrentOrganizationAccess.organization)
    scope = effective_permission_scope(organization:)
    scope.where(permissions: { status: 'active' }).distinct.pluck('permissions.code').to_set
  end

  private

  def effective_permission_scope(organization:)
    assignments = effective_role_assignments(organization:)
    assignments.joins(system_role: :permissions).where(system_role_permissions: { deleted_at: nil })
  end

  def effective_role_assignments(organization:)
    scope = user_roles.active
    return scope.none unless valid_role_context?(organization)

    scope = scope.where(organization:) if organization
    # Without a tenant, only a true global super administrator can act.
    scope = scope.where(organization_id: nil, branch_id: nil) if organization.nil? && CurrentOrganizationAccess.enforce_tenant
    active_branches = Branch.not_deleted.where(operational_status: 'active')
    active_branches = active_branches.where(organization:) if organization
    scope.where(branch_id: nil).or(scope.where(branch_id: active_branches.select(:id)))
  end

  def valid_role_context?(organization)
    return organization_memberships.accessible.exists?(organization:) if organization
    return unscoped_super_admin? if CurrentOrganizationAccess.enforce_tenant
    return true unless organization_memberships.with_deleted.exists?

    organization_memberships.accessible.exists?
  end

  def unscoped_super_admin?
    user_roles.active.where(organization_id: nil, branch_id: nil)
              .exists?(system_roles: { code: 'super_admin', role_type: 'system' })
  end
end
