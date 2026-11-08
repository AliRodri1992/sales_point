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
    effective_permission_scope(organization:).where(permissions: { status: 'active' })
                              .distinct.pluck('permissions.code').to_set
  end

  private

  def effective_permission_scope(organization:)
    effective_role_assignments(organization:).joins(system_role: :permissions)
                              .where(system_role_permissions: { deleted_at: nil })
  end

  def effective_role_assignments(organization:)
    scope = user_roles.active
    active_branches = Branch.not_deleted.where(operational_status: 'active')
    active_branches = active_branches.where(organization:) if organization
    scope.where(branch_id: nil).or(scope.where(branch_id: active_branches.select(:id)))
  end
end
