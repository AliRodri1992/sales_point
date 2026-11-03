# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
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
      @user_status_counts = scoped_users.group(:status).count
      @filter_roles = SystemRole.system.active.not_deleted.order(:name)
    end

    def show
      authorize @user
      @can_manage_users = policy(User).create?
    end

    def new
      @user = User.new(status: 'pending', user_type: 'employee', theme: Theme::DEFAULT)
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
        redirect_to admin_users_path, flash: { swal_message: t('admin.users.created') }
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @user

      if account_writer.save
        notify_user(current_user, @user, 'updated')
        redirect_to admin_user_path(@user), flash: { swal_message: t('admin.users.updated') }
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @user

      @swal_message = destroy_account

      load_users

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_users_path, flash: { swal_message: @swal_message } }
      end
    end

    private

    def set_user
      @user = scoped_users.find(params[:id])
    end

    def scoped_users
      return policy_scope(User).none unless current_organization

      active_members = current_organization.organization_memberships.active
                                           .where(deleted_at: nil).select(:user_id)
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
      UsersQuery.new(scoped_users.includes(user_roles: %i[system_role branch]), params).call
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'users.email'
      sort_direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction)
    end

    def user_params
      params.expect(
        user: [
          :email, :username, :password, :password_confirmation,
          :user_type, :theme, :language_id,
          { system_role_ids: [], branch_role_assignments: [] }
        ]
      )
    end

    def account_writer
      Users::AdminAccountWriter.new(user: @user, organization: current_organization, attributes: user_params)
    end

    def destroy_account
      return t('admin.users.cannot_delete_self') if @user == current_user
      if @user.organization_memberships.active.where.not(organization_id: current_organization.id).exists?
        return t('admin.users.shared_account_cannot_delete')
      end

      @user.update!(status: :deleted, deleted_at: Time.current)
      UserInvitation.revoke_for!(@user)
      notify_user(current_user, @user, 'destroyed')
      t('admin.users.destroyed')
    end

    def load_form_options
      @languages = Language.available.order(:name)
      @themes = Theme.all
      @roles = SystemRole.system.active.not_deleted.order(:name)
      branches = current_organization ? current_organization.branches.not_deleted.where(status: true) : Branch.none
      @branches = branches.order(:name)
      @branch_roles = SystemRole.branch.active.not_deleted.order(:name)
    end

    def notify_user(actor, record, action)
      UserNotification
        .with(action: action, record:, user: actor)
        .deliver(actor, enqueue_job: false)

      actor.broadcast_notifications_refresh
    end
  end
end
