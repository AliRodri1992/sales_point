# frozen_string_literal: true

module Users
  # Prevents one organization from modifying globally shared account details.
  module AdminAccountTenantGuard
    private

    def tenant_safe_update?(role_ids)
      return true if @user.new_record?
      return true unless @user.organization_memberships.active.where.not(organization: @organization).exists?

      field = %i[email username user_type theme language_id].find do |attribute|
        @user.will_save_change_to_attribute?(attribute)
      end
      return reject_shared_change?(field) if field

      original_ids = @user.user_roles.active.where(branch_id: nil).pluck(:system_role_id)
      return true if role_ids.nil? || role_ids.sort == original_ids.sort

      reject_shared_change?(:system_role_ids)
    end

    def last_admin_role_safe?(role_ids)
      return true if @user.new_record? || role_ids.nil? || !@user.admin?

      return true if SystemRole.system.active.exists?(id: role_ids, code: SystemRole::ADMINISTRATIVE_CODES)
      return true if another_administrator_available?

      @user.errors.add(:system_role_ids, :last_administrator)
      false
    end

    def another_administrator_available?
      members = @organization.organization_memberships.accessible
                             .where.not(user_id: @user.id).select(:user_id)
      UserRole.active.where(branch_id: nil, user_id: members)
              .exists?(system_roles: { code: SystemRole::ADMINISTRATIVE_CODES })
    end

    def reject_shared_change?(attribute)
      @user.errors.add(attribute, :shared_account)
      false
    end
  end
end
