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
    @system_role = SystemRole.new
    authorize @system_role
  end

  def create
    @system_role = SystemRole.new(system_role_params)
    authorize @system_role

    if @system_role.save
      redirect_to system_roles_path, notice: t('.success')
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    authorize @system_role
    @system_role.update!(deleted_at: Time.current, status: :deprecated)
    redirect_to system_roles_path, notice: t('.success')
  end

  def update_permissions
    authorize @system_role

    permission_ids = Array(params[:permission_ids]).compact_blank.map(&:to_i)

    Permission.transaction do
      @system_role.system_role_permissions.where.not(permission_id: permission_ids).delete_all

      permission_ids.each do |permission_id|
        @system_role.system_role_permissions.find_or_create_by!(permission_id: permission_id)
      end
    end

    redirect_to system_role_path(@system_role),
                flash: { swal_message: t('admin.system_roles.update_permissions.success') }
  end

  private

  def set_system_role
    @system_role = SystemRole.available.find(params[:id])
  end

  def system_role_params
    params.expect(system_role: %i[name code role_type status description])
  end

  def forbidden
    head :forbidden
  end
end
