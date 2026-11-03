# frozen_string_literal: true

module Admin
  class UserStatusesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :find_user

    def edit
      authorize @user, :update?
      @target = params[:transition].to_s
      head :unprocessable_content unless Users::StatusTransition.allowed_targets(@user, organization: current_organization).include?(@target)
    end

    def update
      authorize @user, :update?
      Users::StatusTransition.new(user: @user, actor: current_user, organization: current_organization,
                                  target: params[:transition], reason: params[:reason]).call!
      destination = @user.deleted? ? admin_users_path : admin_user_path(@user)
      redirect_to destination, flash: { swal_message: t('admin.users.status_management.changed') }
    rescue ArgumentError => e
      redirect_to admin_user_path(@user), alert: e.message
    end

    private

    def find_user
      members = current_organization.organization_memberships.active.where(deleted_at: nil).select(:user_id)
      @user = policy_scope(User).where(id: members).find(params[:user_id])
    end
  end
end
