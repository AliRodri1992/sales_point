# frozen_string_literal: true

# Resolves only roles that can currently grant access to the user.
module UserEffectiveRoles
  def role?(role_code, branch: nil)
    scope = effective_role_assignments.where(system_roles: { code: role_code })
    scope = scope.where(branch:) if branch
    scope.exists?
  end

  def permission?(permission_code)
    effective_permission_scope.exists?(permissions: { code: permission_code, status: 'active' })
  end

  def effective_permission_codes
    effective_permission_scope.where(permissions: { status: 'active' })
                              .distinct.pluck('permissions.code').to_set
  end

  private

  def effective_permission_scope
    effective_role_assignments.joins(system_role: :permissions)
                              .where(system_role_permissions: { deleted_at: nil })
  end

  def effective_role_assignments
    scope = user_roles.active
    active_branches = Branch.not_deleted.where(operational_status: 'active').select(:id)
    scope.where(branch_id: nil).or(scope.where(branch_id: active_branches))
  end
end
