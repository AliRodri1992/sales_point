# frozen_string_literal: true

module Users
  # Keeps the admin account writer's form-level access validation separate
  # from persistence and membership locking.
  module AdminAccountFormValidations
    private

    def prepare_admin_access_validation(role_ids, branch_roles)
      @user.admin_role_selection_required = @user.new_record? || !role_ids.nil? ||
                                            !@attributes[:branch_role_assignments].nil? ||
                                            @user.will_save_change_to_user_type?
      @user.admin_selected_system_roles = role_ids ||
                                          @user.user_roles.active.where(branch_id: nil, organization: @organization).pluck(:system_role_id)
      @user.admin_selected_branch_roles = branch_roles.selected_pairs
    end

    def valid_access_selection?(role_ids, branch_roles)
      return false unless delegated_employee_allowed?

      return invalid_role_error?(:system_role_ids) if role_ids == :invalid
      return invalid_role_error?(:branch_role_assignments) unless branch_roles.valid?

      prepare_admin_access_validation(role_ids, branch_roles)
      true
    end

    def invalid_role_error?(attribute)
      @user.valid?
      @user.errors.add(attribute, :invalid)
      false
    end
  end
end
