# frozen_string_literal: true

module Admin
  class UserRestorationsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action { head :forbidden unless current_organization }
    before_action :verify_restore_permission!

    def index
      load_deleted_users
    end

    def create
      user = restore_target
      @restoration_form = restoration_service(user)
      if @restoration_form.call
        redirect_to admin_user_path(user), notice: t('admin.users.status_management.restored')
      else
        @restoration_error_target_id = user.id
        load_deleted_users
        render :index, status: :unprocessable_content
      end
    rescue ArgumentError, Users::OrganizationCapacity::CapacityExceeded => e
      redirect_to admin_user_restorations_path, alert: e.message
    end

    private

    def restore_target
      members = current_organization.organization_memberships.active
                                    .where(account_status: 'deleted').select(:user_id)
      User.with_deleted.where(id: members).find(params[:user_id])
    end

    def restoration_service(user)
      Users::AccountRestoration.new(
        user:, actor: current_user, organization: current_organization, reason: params[:reason]
      )
    end

    def load_deleted_users
      members = current_organization.organization_memberships.active
                                    .where(account_status: 'deleted').select(:user_id)
      scope = User.with_deleted.where(id: members)
      query = params[:q].to_s.strip
      scope = scope.where('users.email ILIKE :q OR users.username ILIKE :q', q: "%#{query}%") if query.present?
      @total_count = scope.count
      @per_page = 20
      @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
      @current_page = params[:page].to_i.clamp(1, @total_pages)
      @deleted_users = scope.order(created_at: :desc, id: :desc)
                            .limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def verify_restore_permission!
      authorize User, :index?
      authorized = current_user.role?('super_admin') && current_user.permission?('users.restore')
      raise Pundit::NotAuthorizedError unless authorized
    end
  end
end
