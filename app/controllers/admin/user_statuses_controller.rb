# frozen_string_literal: true

module Admin
  class UserStatusesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action { head :forbidden unless current_organization }
    before_action :find_user

    def edit
      authorize @user, :manage_status?
      @target = params[:transition].to_s
      return head :unprocessable_content unless permitted_transition?

      @status_form = Users::StatusTransition.new(**transition_attributes)
    end

    def update
      authorize @user, :manage_status?
      @target = params[:transition].to_s
      return head :unprocessable_content unless permitted_transition?

      @status_form = Users::StatusTransition.new(**transition_attributes)
      return render :edit, status: :unprocessable_content unless @status_form.call

      render_successful_change
    rescue Users::InvitationDispatcher::DeliveryError
      redirect_to admin_user_path(@user), alert: t('admin.users.status_management.invitation_delivery_failed')
    rescue ArgumentError => e
      @status_form.errors.add(:base, Users::StatusErrorPresenter.call(e.message))
      render :edit, status: :unprocessable_content
    end

    private

    def permitted_transition?
      helpers.allowed_user_transitions(@user, organization: current_organization).include?(@target)
    end

    def status_destination
      membership = @user.organization_memberships.active.find_by(organization: current_organization)
      membership&.account_deleted? ? admin_users_path : admin_user_path(@user)
    end

    def render_successful_change
      redirect_to status_destination, flash: { swal_message: t('admin.users.status_management.changed') }
    end

    def transition_attributes
      {
        user: @user, actor: current_user, organization: current_organization,
        target: params[:transition], reason: params[:reason],
        details: { review_at: params[:review_at], resolution: params[:resolution] }
      }
    end

    def find_user
      members = current_organization.organization_memberships.active.where(deleted_at: nil).select(:user_id)
      @user = policy_scope(User).where(id: members).find(params[:user_id])
    end
  end
end
