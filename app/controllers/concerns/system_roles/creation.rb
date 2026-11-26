# frozen_string_literal: true

module SystemRoles
  module Creation
    private

    def persist_role_creation!
      @assigned_permission_ids = selected_permission_ids
      validate_initial_status!

      SystemRole.transaction do
        @system_role.save!
        replace_permissions
      end
    end

    def render_creation_errors
      @system_role.status = :inactive
      load_permissions
      return render :new, status: :unprocessable_content unless modal_creation_request?

      render turbo_stream: turbo_stream.replace(
        'new-role-dialog', partial: 'system_roles/create_modal', locals: { role: @system_role, open: true }
      ), status: :unprocessable_content
    end

    def modal_creation_request?
      params[:role_modal] == '1' && request.format.turbo_stream?
    end
  end
end
