# frozen_string_literal: true

class SystemRolesController < ApplicationController
  include TableListingPagination
  include SystemRoles::History

  layout 'admin_dashboard'

  before_action :authenticate_user!
  before_action :set_system_role, only: %i[show edit update destroy update_permissions]

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  def index
    authorize SystemRole
    @archived = params[:filter] == 'archived'
    @role_search = params[:search].to_s.strip.slice(0, 100)
    @role_type = params[:role_type].presence_in(%w[system branch])
    @role_sort = params[:sort].presence_in(%w[name code recent]) || 'name'

    scope = @archived ? SystemRole.deprecated : SystemRole.available
    @system_roles = paginate_table_listing(sort_directory(filter_directory(scope)), table_key: 'system_roles')
    @role_metrics = {
      total: SystemRole.available.count + SystemRole.deprecated.count,
      active: SystemRole.available.active.count,
      protected: SystemRole.available.where(code: SystemRole::ADMINISTRATIVE_CODES).count,
      archived: SystemRole.deprecated.count
    }
    @new_system_role = SystemRole.new(status: :inactive, role_type: :system) if policy(SystemRole).create?
  end

  def show
    authorize @system_role
    load_permissions
    @assigned_permission_ids = @system_role.permissions.available.ids
    return unless policy(@system_role).audit_history?

    load_status_history
    load_permission_history
  end

  def new
    @system_role = SystemRole.new(status: :inactive, role_type: :system)
    authorize @system_role
    load_permissions
    @assigned_permission_ids = []
  end

  def edit
    authorize @system_role
    show
    render :show
  end

  def create
    @system_role = SystemRole.new(system_role_params)
    authorize @system_role
    @assigned_permission_ids = selected_permission_ids
    validate_initial_status!

    SystemRole.transaction do
      @system_role.save!
      replace_permissions
    end

    notify_system_role(current_user, @system_role, 'created')
    redirect_to system_role_path(@system_role), flash: { swal_message: t('.success') }
  rescue ActiveRecord::RecordInvalid
    @system_role.status = :inactive
    load_permissions
    if params[:role_modal] == '1' && request.format.turbo_stream?
      render turbo_stream: turbo_stream.replace(
        'new-role-dialog', partial: 'system_roles/create_modal', locals: { role: @system_role, open: true }
      ), status: :unprocessable_content
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @system_role
    save_permissions(
      attributes: params.expect(system_role: %i[name status description]),
      change_permissions: params.key?(:permission_ids)
    )
  end

  def update_permissions
    authorize @system_role, :update_permissions?
    save_permissions(change_permissions: true, authorization: :update_permissions?)
  end

  def destroy
    authorize @system_role, :change_status?
    render plain: t('admin.system_roles.lifecycle.errors.review_required'), status: :unprocessable_content
  end

  private

  def save_permissions(attributes: {}, change_permissions: false, authorization: :update?)
    @assigned_permission_ids = change_permissions ? selected_permission_ids : @system_role.permissions.available.ids
    @system_role.with_lock do
      authorize @system_role, authorization
      @system_role.update!(attributes)
      replace_permissions if change_permissions
    end
    notify_system_role(current_user, @system_role, 'updated')
    redirect_to system_role_path(@system_role),
                flash: { swal_message: t('admin.system_roles.update_permissions.success') }
  rescue ActiveRecord::RecordInvalid
    render_invalid_update(attributes)
  end

  def render_invalid_update(attributes)
    @system_role.assign_attributes(attributes.merge(status: @system_role.status_in_database))
    load_permissions
    if policy(@system_role).audit_history?
      load_status_history
      load_permission_history
    end
    render :show, status: :unprocessable_content
  end

  def replace_permissions
    SystemRoles::PermissionUpdater.new(
      role: @system_role, permission_ids: @assigned_permission_ids, actor: current_user
    ).call!
  end

  def filter_directory(scope)
    scope = scope.where(role_type: @role_type) if @role_type
    return scope if @role_search.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@role_search)}%"
    scope.where(
      'system_roles.name ILIKE :pattern OR system_roles.code ILIKE :pattern ' \
      'OR system_roles.description ILIKE :pattern', pattern:
    )
  end

  def sort_directory(scope)
    case @role_sort
    when 'code' then scope.order(:code, :id)
    when 'recent' then scope.order(updated_at: :desc, id: :desc)
    else scope.order(:name, :id)
    end
  end

  def load_permissions
    @permissions = Permission.available.to_a
  end

  def set_system_role
    @system_role = SystemRole.with_deleted.find(params[:id])
  end

  def validate_initial_status!
    @system_role.valid?
    return if @system_role.inactive? && !@system_role.protected_permissions?

    @system_role.errors.add(:status, t('admin.system_roles.lifecycle.errors.create_inactive'))
    raise ActiveRecord::RecordInvalid, @system_role
  end

  def notify_system_role(user, system_role, action)
    SystemRoleNotification.with(action:, record: system_role, user:).deliver(user, enqueue_job: false)
    user.broadcast_notifications_refresh
  end

  def system_role_params
    params.expect(system_role: %i[name code role_type status description])
  end

  def selected_permission_ids
    selection = SystemRoles::PermissionSelection.new(params[:permission_ids])
    @assigned_permission_ids = selection.ids
    return selection.ids if selection.valid?

    @system_role.errors.add(:permission_ids, t("admin.system_roles.form.#{selection.error_key}"))
    raise ActiveRecord::RecordInvalid, @system_role
  end

  def forbidden
    head :forbidden
  end
end
