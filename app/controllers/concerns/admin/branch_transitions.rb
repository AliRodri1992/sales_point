# frozen_string_literal: true

module Admin
  module BranchTransitions
    def transition_status
      authorize @branch, :manage?
      Branches::TransitionStatus.call(branch: @branch, actor: current_user,
                                      to: params[:to_status], reason: params[:reason])
      redirect_to admin_branch_path(@branch, branch_directory_parameters),
                  flash: { swal_message: t('admin.branch_lifecycle.changed') }, status: :see_other
    rescue Branches::TransitionStatus::InvalidTransition, ActiveRecord::RecordInvalid => e
      show_transition_error(e)
    end

    private

    def show_transition_error(error)
      @transition_error = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      @transition_to = params[:to_status].to_s
      @transition_reason = params[:reason].to_s
      @branch.reload
      load_branch_detail
      render :show, status: :unprocessable_content
    end
  end
end
