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
      user = restore_target
      restore_user!(user)
      redirect_to admin_user_path(user), notice: t('admin.users.status_management.restored')
    rescue ArgumentError => e
      redirect_to admin_user_restorations_path, alert: e.message
    end

    private

    def restore_target
      members = current_organization.organization_memberships.active.select(:user_id)
      User.with_deleted.where(id: members, status: 'deleted').find(params[:user_id])
    end

    def restore_user!(user)
      Users::AccountRestoration.new(
        user:, actor: current_user, organization: current_organization, reason: params[:reason]
      ).call!
    end

    def verify_restore_permission!
      authorize User, :index?
      authorized = current_user.role?('super_admin') && current_user.permission?('users.restore')
      raise Pundit::NotAuthorizedError unless authorized
    end
  end
end
