# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action { head :forbidden unless current_organization }
    include CatalogNavigation
    include Admin::UserFormSetup
    include Admin::UserListingSorting

    before_action :set_user, only: %i[show edit update destroy]
    before_action :load_form_options, only: %i[new create edit update]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS
    SORTABLE_COLUMNS = %w[users.email users.username users.user_type users.status users.created_at].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    def index
      authorize User
      load_users
      @can_manage_users = policy(User).create?
      @user_status_counts = current_organization.organization_memberships.active
                                                .where(deleted_at: nil, user_id: scoped_users.select(:id))
                                                .group(:account_status).count
      @filter_roles = SystemRole.active.not_deleted.order(:role_type, :name)
      @filter_branches = current_organization.branches.not_deleted.where(operational_status: 'active').order(:name)
    end

    def show
      authorize @user
      @can_manage_users = policy(@user).update? || policy(@user).manage_status? ||
                          policy(@user).resend_invitation?
    end

    def new
      @user = User.new(status: 'pending', user_type: current_user.admin? ? 'employee' : 'customer',
                       theme: Theme::DEFAULT)
      @user.language = Language.selectable.find_by(code: I18n.locale.to_s) ||
                       Language.selectable.find_by(code: 'es')
      authorize @user
    end

    def edit
      authorize @user
    end

    def create
      return head :forbidden unless current_organization

      @user = User.new
      authorize @user

      if account_writer.save
        Users::InvitationDispatcher.call(user: @user, organization: current_organization)
        notify_user(current_user, @user, 'created')
        return if redirect_without_catalog_listing(@user, :created)

        redirect_to admin_users_path, flash: { swal_message: t('admin.users.created') }
      else
        render :new, status: :unprocessable_content
      end
    end

    rescue_from Users::InvitationDispatcher::DeliveryError, with: :invitation_delivery_failed

    def update
      authorize @user
      writer = account_writer

      if writer.save
        if writer.email_changed? && Users::InvitationEligibility.ready?(user: @user, organization: current_organization)
          Users::InvitationDispatcher.call(user: @user, organization: current_organization)
        end
        notify_user(current_user, @user, 'updated')
        return if redirect_without_catalog_listing(@user, :updated)

        redirect_to admin_user_path(@user), flash: { swal_message: t('admin.users.updated') }
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @user
      head :method_not_allowed
    end

    private

    def set_user
      @user = scoped_users.find(params[:id])
    end

    def scoped_users
      return policy_scope(User).none unless current_organization

      active_members = current_organization.organization_memberships.active
                                           .where(deleted_at: nil)
                                           .where.not(account_status: 'deleted').select(:user_id)
      policy_scope(User).where(id: active_members)
    end

    def load_users
      scope = filtered_users
      @total_count = scope.count
      @per_page = table_page_size_for('users')
      @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
      @current_page = params[:page].to_i.clamp(1, @total_pages)
      @users = apply_sorting(scope).limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def filtered_users
      UsersQuery.new(scoped_users.includes(:organization_memberships, user_roles: [:system_role, { branch: :organization }]), params,
                     organization: current_organization).call
    end

    def user_params
      reject_delegated_role_changes!
      params.expect(
        user: [
          :email, :username,
          :user_type, :theme, :language_id,
          { system_role_ids: [], branch_role_assignments: [] }
        ]
      )
    end

    def reject_delegated_role_changes!
      return if current_user.admin?

      fields = params[:user] || {}
      raise Pundit::NotAuthorizedError if fields.key?(:system_role_ids) || fields.key?(:branch_role_assignments)
    end

    def invitation_delivery_failed
      redirect_to admin_user_path(@user), alert: t('admin.users.status_management.invitation_delivery_failed')
    end

    def notify_user(actor, record, action)
      UserNotification
        .with(action: action, record:, user: actor)
        .deliver(actor, enqueue_job: false)

      actor.broadcast_notifications_refresh
    end
  end
end
