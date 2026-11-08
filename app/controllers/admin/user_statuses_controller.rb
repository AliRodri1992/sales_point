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
      allowed = helpers.allowed_user_transitions(@user, organization: current_organization)
      head :unprocessable_content unless allowed.include?(@target)
      @status_form = Users::StatusTransition.new(**transition_attributes)
    end

    def update
      authorize @user, :manage_status?
      @target = params[:transition].to_s
      @status_form = Users::StatusTransition.new(**transition_attributes)
      if @status_form.call
        membership = @user.organization_memberships.active.find_by(organization: current_organization)
        destination = membership&.account_deleted? ? admin_users_path : admin_user_path(@user)
        redirect_to destination, flash: { swal_message: t('admin.users.status_management.changed') }
      else
        render :edit, status: :unprocessable_content
      end
    rescue ArgumentError => e
      @status_form.errors.add(:base, e.message)
      render :edit, status: :unprocessable_content
    end

    private

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
