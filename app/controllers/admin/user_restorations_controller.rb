# frozen_string_literal: true

module Admin
  class UserRestorationsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :verify_restore_permission!

    def index
      members = current_organization.organization_memberships.active.select(:user_id)
      @deleted_users = User.with_deleted.where(id: members, status: 'deleted')
                           .where.not(deleted_at: nil).order(deleted_at: :desc).limit(100)
    end

    def create
      members = current_organization.organization_memberships.active.select(:user_id)
      user = User.with_deleted.where(id: members, status: 'deleted').find(params[:user_id])
      Users::AccountRestoration.new(
        user:, actor: current_user, organization: current_organization, reason: params[:reason]
      ).call!
      redirect_to admin_user_path(user), notice: t('admin.users.status_management.restored')
    rescue ArgumentError => error
      redirect_to admin_user_restorations_path, alert: error.message
    end

    private

    def verify_restore_permission!
      authorize User, :index?
      raise Pundit::NotAuthorizedError unless current_user.role?('super_admin') &&
                                             current_user.permission?('users.restore')
    end
  end
end
