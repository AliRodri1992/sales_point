# frozen_string_literal: true

class SystemRolesController < ApplicationController
  layout 'admin_dashboard'

  before_action :authenticate_user!
  before_action :set_system_role, only: %i[show destroy update_permissions]

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  def index
    authorize SystemRole
    @system_roles = SystemRole.available.order(:name)
  end

  def show
    authorize @system_role
    @permissions = Permission.available
    @assigned_permission_ids = @system_role.permissions.where(status: :active).pluck(:id)
  end

  def new
    @system_role = SystemRole.new(status: :active, role_type: :system)
    @permissions = Permission.available
    authorize @system_role
  end

  def create
    @system_role = SystemRole.new(system_role_params)
    authorize @system_role

    SystemRole.transaction do
      @system_role.save!
      selected_permission_ids.each do |permission_id|
        @system_role.system_role_permissions.create!(permission_id:)
      end
    end

    notify_system_role(current_user, @system_role, 'created')

    swal_message = t('.success')
    redirect_to system_role_path(@system_role), flash: { swal_message: }
  rescue ActiveRecord::RecordInvalid
    @permissions = Permission.available
    render :new, status: :unprocessable_content
  end

  def destroy
    authorize @system_role
    @system_role.update!(deleted_at: Time.current, status: :deprecated)
    redirect_to system_roles_path, notice: t('.success')
  end

  def update_permissions
    authorize @system_role

    permission_ids = selected_permission_ids

    Permission.transaction do
      @system_role.system_role_permissions.where.not(permission_id: permission_ids).delete_all

      permission_ids.each do |permission_id|
        @system_role.system_role_permissions.find_or_create_by!(permission_id: permission_id)
      end
    end

    notify_system_role(current_user, @system_role, 'updated')

    redirect_to system_role_path(@system_role),
                flash: { swal_message: t('admin.system_roles.update_permissions.success') }
  end

  private

  def set_system_role
    @system_role = SystemRole.available.find(params[:id])
  end

  def notify_system_role(user, system_role, action)
    SystemRoleNotification
      .with(action: action, record: system_role, user: user)
      .deliver(user, enqueue_job: false)

    user.broadcast_notifications_refresh
  end

  def system_role_params
    params.expect(system_role: %i[name code role_type status description])
  end

  # Ids of the permissions checked in the role form.
  def selected_permission_ids
    Array(params[:permission_ids]).compact_blank.map(&:to_i)
  end

  def forbidden
    head :forbidden
  end
end
