# frozen_string_literal: true

module Admin
  module BranchSupport
    def postal_suggestions
      raise Pundit::NotAuthorizedError unless current_organization

      authorize Branch.new(organization: current_organization), :create?
      return head :unprocessable_content unless valid_postal_lookup_params?

      suggestion = Suppliers::MexicanPostalLookup.new(params[:postal_code]).call
      return head :service_unavailable unless suggestion

      response.headers['Cache-Control'] = 'private, no-store'
      render json: suggestion
    end

    private

    def valid_postal_lookup_params?
      params[:country] == 'MX' && /\A\d{5}\z/.match?(params[:postal_code].to_s)
    end

    def render_destroyed_branch
      notify_branch(current_user, @branch, 'destroyed')
      load_branches
      @can_manage_branches = current_organization.present? && policy(Branch).create?

      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.branches.destroyed') }
        format.html do
          redirect_to branch_directory_path,
                      flash: { swal_message: t('admin.branches.destroyed') }
        end
      end
    end

    def notify_branch(user, branch, action)
      BranchNotification
        .with(action: action, record: branch, user:)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end
  end
end
