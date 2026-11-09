# frozen_string_literal: true

class SystemRolesController < ApplicationController
  include TableListingPagination

  layout 'admin_dashboard'

  before_action :authenticate_user!
  before_action :set_system_role, only: %i[show edit update destroy update_permissions]

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  def index
    authorize SystemRole
    @archived = params[:filter] == 'archived'
    scope = @archived ? SystemRole.deprecated : SystemRole.available
    @system_roles = paginate_table_listing(scope.order(:name, :id), table_key: 'system_roles')
  end

  def show
    authorize @system_role
    load_permissions
    @assigned_permission_ids = @system_role.permissions.available.ids
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
    render :new, status: :unprocessable_content
  end

  def update
    authorize @system_role
    params[:permission_ids] = @system_role.permissions.available.ids unless params.key?(:permission_ids)
    save_permissions(attributes: params.expect(system_role: %i[name status description]))
  end

  def update_permissions
    authorize @system_role, :update_permissions?
    save_permissions
  end

  def destroy
    authorize @system_role, :change_status?
    render plain: t('admin.system_roles.lifecycle.errors.review_required'), status: :unprocessable_content
  end

  private

  def save_permissions(attributes: {})
    @assigned_permission_ids = selected_permission_ids
    @system_role.with_lock do
      authorize @system_role, :update?
      @system_role.update!(attributes)
      replace_permissions
    end
    notify_system_role(current_user, @system_role, 'updated')
    redirect_to system_role_path(@system_role),
                flash: { swal_message: t('admin.system_roles.update_permissions.success') }
  rescue ActiveRecord::RecordInvalid
    @system_role.status = @system_role.status_in_database
    load_permissions
    load_status_history
    load_permission_history
    render :show, status: :unprocessable_content
  end

  def replace_permissions
    previous_codes = @system_role.permissions.pluck(:code)
    selected_codes = Permission.where(id: @assigned_permission_ids).pluck(:code)

    @system_role.system_role_permissions.where.not(permission_id: @assigned_permission_ids).delete_all
    @assigned_permission_ids.each do |permission_id|
      @system_role.system_role_permissions.find_or_create_by!(permission_id:)
    end

    added = selected_codes - previous_codes
    removed = previous_codes - selected_codes
    return if added.empty? && removed.empty?

    @system_role.permission_audit_events.create!(
      actor: current_user, added_permission_codes: added.sort, removed_permission_codes: removed.sort
    )
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

  def load_status_history
    scope = @system_role.status_events.includes(:actor).order(created_at: :desc, id: :desc)
    @history_pages = [(scope.count / 10.0).ceil, 1].max
    @history_page = params[:history_page].to_i.clamp(1, @history_pages)
    @status_events = scope.limit(10).offset((@history_page - 1) * 10)
  end

  def load_permission_history
    @permission_audit_events = @system_role.permission_audit_events.includes(:actor)
                                           .order(created_at: :desc, id: :desc).limit(20)
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
