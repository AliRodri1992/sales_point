# frozen_string_literal: true

module Admin
  # Small administrative actions for preparing and retiring branch registers.
  module BranchTerminals
    def add_terminal
      authorize @branch, :manage?
      ensure_terminal_setup_allowed!
      @terminal = @branch.terminals.build(name: terminal_params[:name], status: 'inactive')
      create_branch_terminal!
      redirect_to admin_branch_path(@branch, anchor: 'branch-detail-operations'),
                  flash: { swal_message: t('admin.branch_lifecycle.terminal_added') }, status: :see_other
    rescue ActiveRecord::RecordInvalid => e
      render_terminal_error(e)
    rescue Branches::TransitionStatus::InvalidTransition => e
      redirect_to admin_branch_path(@branch), alert: e.message, status: :see_other
    end

    def change_terminal
      authorize @branch, :manage?
      target_status = params[:terminal_status].to_s
      ensure_terminal_status_allowed!(target_status)
      update_branch_terminal!(params[:terminal_id], target_status)
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

    def ensure_terminal_setup_allowed!
      return if @branch.preparing? || @branch.active?

      raise Branches::TransitionStatus::InvalidTransition, :invalid_transition
    end

    def ensure_terminal_status_allowed!(status)
      allowed = %w[active inactive].include?(status)
      allowed &&= @branch.active? if status == 'active'
      return if allowed

      raise Branches::TransitionStatus::InvalidTransition, :invalid_transition
    end

    def create_branch_terminal!
      @branch.with_lock do
        @terminal.code = next_branch_terminal_code
        @terminal.save!
      end
    end

    def update_branch_terminal!(terminal_id, status)
      @branch.with_lock do
        terminal = @branch.terminals.not_deleted.find(terminal_id)
        terminal.update!(status:)
      end
    end

    def render_terminal_error(error)
      @terminal ||= error.record
      @terminal_error = @terminal.errors[:name].any?
      @terminal_operation_error = @terminal.errors.full_messages_for(:branch).to_sentence
      @terminal_operation_error = error.message if @terminal_operation_error.blank? && !@terminal_error
      load_branch_detail
      render :show, status: :unprocessable_content
    end

    def next_branch_terminal_code
      highest = @branch.terminals.with_deleted.where('code ~ ?', '^POS-[0-9]+
  end
end
)
                       .pick(Arel.sql('MAX(SUBSTRING(code FROM 5)::numeric)'))
      format('POS-%03d', highest.to_i + 1)
    end
  end
end
