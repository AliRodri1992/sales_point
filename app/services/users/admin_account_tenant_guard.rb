# frozen_string_literal: true

module Users
  # Prevents one organization from modifying globally shared account details.
  module AdminAccountTenantGuard
    private

    def tenant_safe_update?
      return true if @user.new_record?
      return true unless @user.organization_memberships.active.where.not(organization: @organization).exists?

      field = %i[email username user_type theme language_id].find do |attribute|
        @user.will_save_change_to_attribute?(attribute)
      end
      return reject_shared_change?(field) if field

      # Role grants are organization-scoped; shared identity fields remain protected.
      true
    end

    def delegated_employee_allowed?
      return true unless @user.new_record? && @user.employee? && @actor && !@actor.admin?

      @user.errors.add(:user_type, I18n.t('admin.users.ui.delegated_employee_restricted'))
      false
    end

    def last_admin_role_safe?(role_ids)
      return true if @user.new_record? || role_ids.nil?

      local_admin = @user.user_roles.active.where(organization: @organization, branch_id: nil)
                         .exists?(system_roles: { code: SystemRole::ADMINISTRATIVE_CODES })
      return true unless local_admin

      return true if SystemRole.system.active.exists?(id: role_ids, code: SystemRole::ADMINISTRATIVE_CODES)
      return true if another_administrator_available?

      @user.errors.add(:system_role_ids, :last_administrator)
      false
    end

    def another_administrator_available?
      members = @organization.organization_memberships.accessible
                             .where.not(user_id: @user.id).select(:user_id)
      UserRole.active.where(branch_id: nil, user_id: members, organization: @organization)
              .joins(:user)
              .where(users: { status: 'active', deleted_at: nil })
              .exists?(system_roles: { code: SystemRole::ADMINISTRATIVE_CODES })
    end

    def reject_shared_change?(attribute)
      @user.errors.add(attribute, :shared_account)
      false
    end
  end
end
