# frozen_string_literal: true

module SystemRoles
  class StatusImpact
    def initialize(role)
      @role = role
    end

    def counts
      {
        users: user_ids.size, assignments: assignments.size,
        branches: assignments.filter_map { |row| row[2] }.uniq.size,
        without_other_roles: (user_ids - effective_other_user_ids).size,
        permissions: permissions.size
      }
    end

    def fingerprint
      Digest::SHA256.hexdigest([
        @role.id, @role.status, @role.updated_at.iso8601(6), @role.deleted_at,
        assignments, permissions, other_assignments, affected_branch_states
      ].to_json)
    end

    def affected_users(organization:)
      return User.none unless organization

      local_ids = organization.organization_memberships.select(:user_id)
      User.where(id: user_ids).where(id: local_ids).order(:username, :id)
    end

    private

    def user_ids
      @user_ids ||= assignments.pluck(1).uniq
    end

    def assignments
      @assignments ||= @role.user_roles.order(:id).pluck(:id, :user_id, :branch_id, :updated_at)
    end

    def permissions
      @permissions ||= @role.permissions.available.reorder(:id).pluck(:id, :code, :updated_at)
    end

    def effective_other_user_ids
      return [] if user_ids.empty?

      scope = UserRole.active.where(user_id: user_ids).where.not(system_role_id: @role.id)
      active_branches = Branch.not_deleted.where(operational_status: 'active').select(:id)
      scope.where(branch_id: nil).or(scope.where(branch_id: active_branches)).distinct.pluck(:user_id)
    end

    def affected_branch_states
      branch_ids = (assignments.pluck(2) + other_assignments.pluck(3)).compact.uniq
      Branch.with_deleted.where(id: branch_ids).order(:id).pluck(:id, :operational_status, :deleted_at, :updated_at)
    end

    def other_assignments
      @other_assignments ||= UserRole.active.where(user_id: user_ids).where.not(system_role_id: @role.id)
                                     .order(:id).pluck(:id, :user_id, :system_role_id, :branch_id)
    end
  end
end
