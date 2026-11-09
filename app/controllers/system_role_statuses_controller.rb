# frozen_string_literal: true

class SystemRoleStatusesController < ApplicationController
  layout 'admin_dashboard'
  before_action :authenticate_user!
  before_action :load_role

  def show
    prepare_review
    render 'system_roles/status_review', status: @allowed_transition ? :ok : :unprocessable_content
  end

  def update
    SystemRoles::StatusTransition.new(
      role: @system_role, actor: current_user, target: params[:target], reason: params[:reason],
      review_token: params[:review_token], confirmed: params[:confirmed]
    ).call!
    redirect_to system_role_path(@system_role), flash: { swal_message: t('admin.system_roles.lifecycle.success') }
  rescue SystemRoles::StatusTransition::InvalidTransition, ActiveRecord::RecordInvalid => e
    case e.respond_to?(:key) ? e.key : nil
    when :reason_required then @reason_error = e.message
    when :confirmation_required then @confirmation_error = e.message
    else @status_error = e.message
    end
    @system_role.reload
    prepare_review
    render 'system_roles/status_review', status: :unprocessable_content
  end

  private

  def load_role
    @system_role = SystemRole.with_deleted.find(params[:id])
    authorize @system_role, :change_status?
  end

  def prepare_review
    @target = params[:target].to_s
    @impact = SystemRoles::StatusImpact.new(@system_role)
    @affected_users = @impact.affected_users(organization: current_organization).limit(50)
    @review_token = SystemRoles::StatusReview.new(
      role: @system_role, actor: current_user, target: @target, impact: @impact
    ).token
    @allowed_transition = SystemRole::STATUS_TRANSITIONS.fetch(@system_role.status, []).include?(@target)
  end
end
