# frozen_string_literal: true

module Admin
  # Small administrative actions for preparing and retiring branch registers.
  module BranchTerminals
    def add_terminal
      authorize @branch, :manage?
      raise Branches::TransitionStatus::InvalidTransition, :invalid_transition unless @branch.preparing? || @branch.active?

      @terminal = @branch.terminals.build(name: terminal_params[:name], status: 'inactive')
      @branch.with_lock do
        @terminal.code = next_branch_terminal_code
        @terminal.save!
      end
      redirect_to admin_branch_path(@branch, anchor: 'branch-detail-operations'),
                  flash: { swal_message: t('admin.branch_lifecycle.terminal_added') }, status: :see_other
    rescue ActiveRecord::RecordInvalid => e
      @terminal ||= e.record
      @terminal_error = true
      load_branch_detail
      render :show, status: :unprocessable_content
    rescue Branches::TransitionStatus::InvalidTransition => e
      redirect_to admin_branch_path(@branch), alert: e.message, status: :see_other
    end

    def change_terminal
      authorize @branch, :manage?
      terminal = @branch.terminals.find(params[:terminal_id])
      status = params[:terminal_status].to_s
      raise Branches::TransitionStatus::InvalidTransition, :invalid_transition unless %w[active inactive].include?(status)
      raise Branches::TransitionStatus::InvalidTransition, :invalid_transition if status == 'active' && !@branch.active?

      @branch.with_lock do
        terminal.reload
        terminal.update!(status:)
      end
      redirect_to admin_branch_path(@branch, anchor: 'branch-detail-operations'),
                  flash: { swal_message: t('admin.branch_lifecycle.terminal_updated') }, status: :see_other
    rescue ActiveRecord::RecordInvalid, Branches::TransitionStatus::InvalidTransition => e
      redirect_to admin_branch_path(@branch, anchor: 'branch-detail-operations'),
                  alert: e.message, status: :see_other
    end

    private

    def terminal_params
      params.expect(terminal: [:name])
    end

    def next_branch_terminal_code
      number = 1
      number += 1 while @branch.terminals.with_deleted.exists?(code: format('POS-%03d', number))
      format('POS-%03d', number)
    end
  end
end
