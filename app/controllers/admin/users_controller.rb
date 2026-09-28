# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_user, only: %i[show edit update destroy]
    before_action :load_form_options, only: %i[new create edit update]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze
    SORTABLE_COLUMNS = %w[users.email users.username users.user_type users.status users.created_at].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    def index
      authorize User
      load_users
      @can_manage_users = policy(User).create?
    end

    def show
      authorize @user
      @can_manage_users = policy(User).create?
    end

    def new
      @user = User.new(status: 'active', user_type: 'employee', theme: Theme::DEFAULT)
      authorize @user
    end

    def edit
      authorize @user
    end

    def create
      @user = User.new(user_params)
      authorize @user

      if @user.save
        notify_user(current_user, @user, 'created')
        redirect_to admin_users_path, flash: { swal_message: t('admin.users.created') }
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @user

      if @user.update(user_params)
        notify_user(current_user, @user, 'updated')
        redirect_to admin_user_path(@user), flash: { swal_message: t('admin.users.updated') }
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @user

      if @user == current_user
        @swal_message = t('admin.users.cannot_delete_self')
      else
        @user.update!(deleted_at: Time.current)
        notify_user(current_user, @user, 'destroyed')
        @swal_message = t('admin.users.destroyed')
      end

      load_users

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_users_path, flash: { swal_message: @swal_message } }
      end
    end

    private

    def set_user
      @user = policy_scope(User).find(params[:id])
    end

    def load_users
      scope = filtered_users
      @total_count = scope.count
      @per_page = per_page_param(@total_count)
      @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
      @current_page = params[:page].to_i.clamp(1, @total_pages)
      @users = apply_sorting(scope).limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def filtered_users
      UsersQuery.new(policy_scope(User).includes(:system_roles), params).call
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'users.email'
      sort_direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction)
    end

    def per_page_param(total_count)
      return PER_PAGE if total_count <= PER_PAGE

      value = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : PER_PAGE
    end

    def user_params
      params.expect(
        user: [
          :email, :username, :password, :password_confirmation,
          :user_type, :status, :theme, :language_id,
          { system_role_ids: [] }
        ]
      )
    end

    def load_form_options
      @languages = Language.available.order(:name)
      @themes = Theme.all
      @roles = SystemRole.system.active.order(:name)
    end

    def notify_user(actor, record, action)
      UserNotification
        .with(action: action, record:, user: actor)
        .deliver(actor, enqueue_job: false)

      actor.broadcast_notifications_refresh
    end

    def forbidden
      head :forbidden
    end
  end
end
