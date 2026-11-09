# frozen_string_literal: true

module Users
  # Protects active, tenant-local administrator coverage during status changes.
  module StatusAdminSafety
    private

    def prevent_last_admin!
      return unless @user.role?('administrator', organization: @organization) ||
                    @user.role?('super_admin', organization: @organization)
      return if @target == 'active'

      members = @organization.organization_memberships.accessible.select(:user_id)
      remaining = UserRole.active.where(branch_id: nil, organization: @organization)
                          .where(user_id: members)
                          .where.not(user_id: @user.id)
                          .joins(:user)
                          .where(users: { status: 'active', deleted_at: nil })
                          .where(system_roles: { code: SystemRole::ADMINISTRATIVE_CODES })
      raise ArgumentError, 'Cannot disable the last administrator' unless remaining.exists?
    end
  end
end
