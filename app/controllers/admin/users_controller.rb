# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_user, only: %i[show edit update destroy]
    before_action :load_form_options, only: %i[new create edit update]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    PER_PAGE = 10
    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS
    SORTABLE_COLUMNS = %w[users.email users.username users.user_type users.status users.created_at].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    def index
      authorize User
      load_users
      @can_manage_users = policy(User).create?
      @user_status_counts = scoped_users.group(:status).count
      @filter_roles = SystemRole.system.active.order(:name)
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
      return head :forbidden unless current_organization

      @user = User.new(user_attributes)
      authorize @user

      if persist_user
        notify_user(current_user, @user, 'created')
        redirect_to admin_users_path, flash: { swal_message: t('admin.users.created') }
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @user
      @user.assign_attributes(user_attributes)

      if persist_user
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
      elsif @user.organization_memberships.active.where.not(organization_id: current_organization.id).exists?
        @swal_message = t('admin.users.shared_account_cannot_delete')
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
      @user = scoped_users.find(params[:id])
    end

    def scoped_users
      return policy_scope(User).none unless current_organization

      policy_scope(User)
        .joins(:organization_memberships)
        .where(organization_memberships: {
          organization_id: current_organization.id,
          status: 'active',
          deleted_at: nil
        })
        .distinct
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
      UsersQuery.new(scoped_users.includes(user_roles: %i[system_role branch]), params).call
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'users.email'
      sort_direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction)
    end

    def per_page_param(_total_count)
      table_page_size_for('users')
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

    def user_attributes
      attributes = user_params.except(:system_role_ids)
      if attributes[:password].blank?
        attributes.delete(:password)
        attributes.delete(:password_confirmation) if attributes[:password_confirmation].blank?
      end
      attributes
    end

    def requested_system_role_ids
      values = user_params[:system_role_ids]
      return nil if values.nil?

      provided = Array(values).reject(&:blank?)
      return :invalid unless provided.all? { |value| value.to_s.match?(/\A\d+\z/) }

      ids = provided.map(&:to_i).uniq
      allowed = SystemRole.system.active.where(id: ids).pluck(:id)
      ids.sort == allowed.sort ? ids : :invalid
    end

    def persist_user
      role_ids = requested_system_role_ids
      if role_ids == :invalid
        @user.valid?
        @user.errors.add(:system_role_ids, :invalid)
        return false
      end

      User.transaction do
        @user.save!
        if @user.previously_new_record?
          @user.organization_memberships.create!(organization: current_organization, status: :active)
        end
        sync_system_roles!(role_ids) unless role_ids.nil?
      end
      true
    rescue ActiveRecord::RecordInvalid => error
      @user.errors.add(:base, error.message) if @user.errors.empty?
      false
    end

    def sync_system_roles!(role_ids)
      active_roles = @user.user_roles.active.where(branch_id: nil).where(system_roles: { role_type: 'system' })
      existing_ids = active_roles.pluck(:system_role_id)
      active_roles.where.not(system_role_id: role_ids).update_all(deleted_at: Time.current, updated_at: Time.current)
      (role_ids - existing_ids).each { |id| @user.user_roles.create!(system_role_id: id) }
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
