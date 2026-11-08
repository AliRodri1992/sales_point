# frozen_string_literal: true

# Resolves only roles that can currently grant access to the user.
module UserEffectiveRoles
  def role?(role_code, branch: nil)
    scope = effective_role_assignments.where(system_roles: { code: role_code })
    scope = scope.where(branch:) if branch
    scope.exists?
  end

  def permission?(permission_code)
    effective_role_assignments
      .joins(system_role: :permissions)
      .exists?(permissions: { code: permission_code, status: 'active' })
  end

  private

  def effective_role_assignments
    scope = user_roles.active
    active_branches = Branch.not_deleted.where(operational_status: 'active').select(:id)
    scope.where(branch_id: nil).or(scope.where(branch_id: active_branches))
  end
end
