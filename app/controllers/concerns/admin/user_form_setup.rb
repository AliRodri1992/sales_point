# frozen_string_literal: true

module Admin
  # Options and persistence wiring shared by new and edit user screens.
  module UserFormSetup
    private

    def account_writer
      Users::AdminAccountWriter.new(
        user: @user, organization: current_organization, attributes: user_params, actor: current_user
      )
    end

    def load_form_options
      @languages = Language.selectable.or(Language.where(id: @user&.language_id)).order(:name)
      @themes = Theme.all
      selectable_roles = organization_selectable_roles
      @roles = selectable_roles.system
      @roles = @roles.where.not(code: SystemRole::ADMINISTRATIVE_CODES) unless current_user.role?('super_admin')
      @roles = @roles.order(:name)
      @branches = Users::BranchRoleAssignments.branch_options(user: @user, organization: current_organization)
      @branch_roles = selectable_roles.branch.order(:name)
    end

    def organization_selectable_roles
      retained_ids = if @user&.persisted?
                       @user.user_roles.where(organization: current_organization).select(:system_role_id)
                     else
                       []
                     end
      SystemRole.available.where(status: 'active').or(SystemRole.available.where(id: retained_ids))
    end
  end
end
